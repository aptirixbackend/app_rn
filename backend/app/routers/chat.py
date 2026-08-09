"""Real-time 1:1 chat (WhatsApp-style).

Transport:
- WebSocket  /chat/ws/{token}  — the token is one of our session JWTs (passed
  in the URL because a WS handshake can't carry an Authorization header). Carries
  live messages, typing indicators, read receipts and presence.
- REST  /chat/*  — conversation list, message history, unread count. Used to
  hydrate the UI; the socket keeps it live.

Storage is Supabase Postgres via the service key (see database.get_supabase).
supabase-py is synchronous, so every DB call here is pushed to a worker thread
with asyncio.to_thread — the single event loop that fans out all sockets never
blocks on the database.
"""
import asyncio
import logging

from fastapi import (
    APIRouter,
    Depends,
    Query,
    WebSocket,
    WebSocketDisconnect,
)

from .. import fcm
from ..auth import get_current_user
from ..database import get_supabase
from ..otp_auth import decode_token

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/chat", tags=["chat"])

_DEFAULT_NAME = "RentoRent User"


async def _run(fn):
    """Run a blocking supabase-py call off the event loop."""
    return await asyncio.to_thread(fn)


# --------------------------------------------------------------------------- #
# Connection registry
# --------------------------------------------------------------------------- #
class ConnectionManager:
    """Tracks live sockets per user. A user may have several (multiple devices),
    so each user_id maps to a *set* of sockets."""

    def __init__(self) -> None:
        self._conns: dict[str, set[WebSocket]] = {}

    async def connect(self, user_id: str, ws: WebSocket) -> None:
        await ws.accept()
        first = not self._conns.get(user_id)
        self._conns.setdefault(user_id, set()).add(ws)
        if first:
            await self._broadcast_presence(user_id, True)

    async def disconnect(self, user_id: str, ws: WebSocket) -> None:
        conns = self._conns.get(user_id)
        if not conns:
            return
        conns.discard(ws)
        if not conns:
            self._conns.pop(user_id, None)
            await self._broadcast_presence(user_id, False)

    def is_online(self, user_id: str) -> bool:
        return bool(self._conns.get(user_id))

    async def send_to_user(self, user_id: str, message: dict) -> None:
        for ws in list(self._conns.get(user_id, ())):
            try:
                await ws.send_json(message)
            except Exception:  # noqa: BLE001 — drop dead sockets
                self._conns.get(user_id, set()).discard(ws)

    async def _broadcast_presence(self, user_id: str, online: bool) -> None:
        event = {"type": "presence", "user_id": user_id, "online": online}
        for uid, conns in list(self._conns.items()):
            if uid == user_id:
                continue
            for ws in list(conns):
                try:
                    await ws.send_json(event)
                except Exception:  # noqa: BLE001
                    pass


manager = ConnectionManager()


# --------------------------------------------------------------------------- #
# DB helpers (all synchronous — call through _run)
# --------------------------------------------------------------------------- #
def _profile(uid: str) -> dict | None:
    sb = get_supabase()
    r = (
        sb.table("profiles_home")
        .select("id, first_name, avatar_url, phone")
        .eq("id", uid)
        .limit(1)
        .execute()
    )
    return r.data[0] if r.data else None


def _name_of(prof: dict | None) -> str:
    if prof and (prof.get("first_name") or "").strip():
        return prof["first_name"]
    return _DEFAULT_NAME


def _insert_message(
    sender_id: str,
    receiver_id: str,
    body: str,
    image_url: str,
    message_type: str,
    status: str,
    property_id: str | None,
) -> dict | None:
    sb = get_supabase()
    row = {
        "sender_id": sender_id,
        "receiver_id": receiver_id,
        "body": body,
        "image_url": image_url or "",
        "message_type": message_type or "text",
        "status": status,
    }
    if property_id:
        row["property_id"] = property_id
    res = sb.table("messages_home").insert(row).execute()
    return res.data[0] if res.data else None


def _mark_delivered(user_id: str) -> list[dict]:
    """Flip every 'sent' message addressed to this user to 'delivered' (they've
    just come online). Returns the updated rows so we can notify each sender."""
    sb = get_supabase()
    res = (
        sb.table("messages_home")
        .update({"status": "delivered"})
        .eq("receiver_id", user_id)
        .eq("status", "sent")
        .execute()
    )
    return res.data or []


def _mark_read(sender_id: str, receiver_id: str) -> list[str]:
    """Mark messages sender_id -> receiver_id as read. Returns the ids changed."""
    sb = get_supabase()
    sel = (
        sb.table("messages_home")
        .select("id")
        .eq("sender_id", sender_id)
        .eq("receiver_id", receiver_id)
        .neq("status", "read")
        .execute()
    )
    ids = [str(r["id"]) for r in (sel.data or [])]
    if ids:
        (
            sb.table("messages_home")
            .update({"status": "read"})
            .eq("sender_id", sender_id)
            .eq("receiver_id", receiver_id)
            .neq("status", "read")
            .execute()
        )
    return ids


def _payload(row: dict, sender_name: str) -> dict:
    return {
        "type": "message",
        "id": str(row["id"]),
        "sender_id": str(row["sender_id"]),
        "receiver_id": str(row["receiver_id"]),
        "message": row.get("body") or "",
        "image_url": row.get("image_url") or "",
        "message_type": row.get("message_type") or "text",
        "property_id": str(row["property_id"]) if row.get("property_id") else None,
        "status": row.get("status") or "sent",
        "timestamp": row.get("created_at"),
        "sender_name": sender_name or "",
    }


# --------------------------------------------------------------------------- #
# WebSocket
# --------------------------------------------------------------------------- #
@router.websocket("/ws/{token}")
async def chat_ws(websocket: WebSocket, token: str) -> None:
    claims = decode_token(token)
    if not claims or not claims.get("sub"):
        await websocket.close(code=4001)
        return
    user_id = str(claims["sub"])

    me = await _run(lambda: _profile(user_id))
    if not me:
        await websocket.close(code=4001)
        return
    my_name = _name_of(me)

    await manager.connect(user_id, websocket)

    # Coming online: everything queued as 'sent' for me is now 'delivered'.
    try:
        delivered = await _run(lambda: _mark_delivered(user_id))
        for sid in {str(r["sender_id"]) for r in delivered}:
            await manager.send_to_user(sid, {"type": "delivered", "user_id": user_id})
    except Exception as exc:  # noqa: BLE001
        logger.warning("mark-delivered on connect failed: %s", exc)

    try:
        while True:
            data = await websocket.receive_json()
            mtype = data.get("type", "message")

            if mtype == "message":
                receiver_id = str(data.get("receiver_id") or "")
                body = (data.get("message") or "").strip()
                image_url = data.get("image_url") or ""
                message_type = data.get("message_type") or "text"
                property_id = data.get("property_id") or None
                if not receiver_id or (not body and not image_url):
                    continue

                status = "delivered" if manager.is_online(receiver_id) else "sent"
                row = await _run(
                    lambda: _insert_message(
                        user_id, receiver_id, body, image_url,
                        message_type, status, property_id,
                    )
                )
                if not row:
                    await websocket.send_json(
                        {"type": "error", "message": "Failed to send message"}
                    )
                    continue

                payload = _payload(row, my_name)
                await manager.send_to_user(receiver_id, payload)   # to them
                await websocket.send_json(payload)                 # echo to me

                # Offline receiver → wake them with a push (gated by settings).
                if not manager.is_online(receiver_id):
                    preview = (
                        "📷 Photo" if message_type == "image"
                        else (body or "New message")[:80]
                    )
                    try:
                        await fcm.notify_user(
                            receiver_id, "notif_messages", my_name, preview,
                            {"type": "new_message", "sender_id": user_id},
                        )
                    except Exception as exc:  # noqa: BLE001
                        logger.warning("chat push failed: %s", exc)

            elif mtype == "read":
                sender_id = str(data.get("sender_id") or "")
                if not sender_id:
                    continue
                ids = await _run(lambda: _mark_read(sender_id, user_id))
                if ids:
                    await manager.send_to_user(
                        sender_id,
                        {"type": "read_receipt", "reader_id": user_id,
                         "message_ids": ids},
                    )

            elif mtype == "typing":
                receiver_id = str(data.get("receiver_id") or "")
                if receiver_id:
                    await manager.send_to_user(
                        receiver_id,
                        {"type": "typing", "sender_id": user_id,
                         "sender_name": my_name},
                    )

    except WebSocketDisconnect:
        await manager.disconnect(user_id, websocket)
    except Exception as exc:  # noqa: BLE001
        logger.warning("chat ws error (user %s): %s", user_id, exc)
        await manager.disconnect(user_id, websocket)


# --------------------------------------------------------------------------- #
# REST
# --------------------------------------------------------------------------- #
@router.get("/conversations")
async def conversations(current: dict = Depends(get_current_user)):
    """Latest message per partner + unread count, newest first."""
    me = str(current["id"])

    def build():
        sb = get_supabase()
        rows = (
            sb.table("messages_home")
            .select("*")
            .or_(f"sender_id.eq.{me},receiver_id.eq.{me}")
            .order("created_at", desc=True)
            .limit(1000)
            .execute()
        ).data or []

        latest: dict[str, dict] = {}
        unread: dict[str, int] = {}
        for r in rows:
            partner = (
                str(r["receiver_id"]) if str(r["sender_id"]) == me
                else str(r["sender_id"])
            )
            if partner not in latest:
                latest[partner] = r  # rows are desc → first seen is newest
            if str(r["receiver_id"]) == me and r.get("status") != "read":
                unread[partner] = unread.get(partner, 0) + 1

        profs: dict[str, dict] = {}
        if latest:
            pr = (
                sb.table("profiles_home")
                .select("id, first_name, avatar_url")
                .in_("id", list(latest.keys()))
                .execute()
            )
            profs = {str(p["id"]): p for p in (pr.data or [])}

        out = []
        for pid, last in latest.items():
            prof = profs.get(pid, {})
            preview = (
                "📷 Photo" if last.get("message_type") == "image"
                else (last.get("body") or "")
            )
            out.append({
                "user_id": pid,
                "user_name": _name_of(prof),
                "user_image": prof.get("avatar_url") or None,
                "last_message": preview,
                "last_message_time": last.get("created_at"),
                "last_sender_id": str(last["sender_id"]),
                "unread_count": unread.get(pid, 0),
            })
        out.sort(key=lambda x: x["last_message_time"] or "", reverse=True)
        return out

    return await _run(build)


@router.get("/with/{user_id}")
async def history(
    user_id: str,
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    current: dict = Depends(get_current_user),
):
    """Full thread with `user_id`, oldest first, and mark their messages read."""
    me = str(current["id"])
    other = str(user_id)

    def build():
        sb = get_supabase()
        rows = (
            sb.table("messages_home")
            .select("*")
            .or_(
                f"and(sender_id.eq.{me},receiver_id.eq.{other}),"
                f"and(sender_id.eq.{other},receiver_id.eq.{me})"
            )
            .order("created_at", desc=False)
            .range(skip, skip + limit - 1)
            .execute()
        ).data or []

        # Opening the thread reads everything they sent me.
        (
            sb.table("messages_home")
            .update({"status": "read"})
            .eq("sender_id", other)
            .eq("receiver_id", me)
            .neq("status", "read")
            .execute()
        )

        pr = (
            sb.table("profiles_home")
            .select("id, first_name, avatar_url, phone")
            .eq("id", other)
            .limit(1)
            .execute()
        )
        prof = pr.data[0] if pr.data else {"id": other}
        return {
            "partner": {
                "user_id": other,
                "user_name": _name_of(prof),
                "user_image": prof.get("avatar_url") or None,
                "phone": prof.get("phone"),
                "online": manager.is_online(other),
            },
            "messages": [_payload(r, "") for r in rows],
        }

    return await _run(build)


@router.post("/with/{user_id}/read")
async def mark_conversation_read(
    user_id: str, current: dict = Depends(get_current_user)
):
    me = str(current["id"])
    other = str(user_id)

    def go():
        get_supabase().table("messages_home").update({"status": "read"}).eq(
            "sender_id", other
        ).eq("receiver_id", me).neq("status", "read").execute()

    await _run(go)
    return {"status": "ok"}


@router.get("/unread-count")
async def unread_count(current: dict = Depends(get_current_user)):
    me = str(current["id"])

    def go():
        res = (
            get_supabase()
            .table("messages_home")
            .select("id", count="exact")
            .eq("receiver_id", me)
            .neq("status", "read")
            .execute()
        )
        return res.count or 0

    return {"count": await _run(go)}
