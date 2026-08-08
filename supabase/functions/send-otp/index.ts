// Supabase Auth "Send SMS" hook → delivers the login OTP through Plivo.
//
// Supabase still GENERATES and VERIFIES the code; this function only delivers
// it. It tries WhatsApp first (an approved "authentication" template — no DLT
// needed in India) and falls back to SMS.
//
// Deploy:
//   supabase functions deploy send-otp --no-verify-jwt
// Set secrets (never in the app):
//   supabase secrets set PLIVO_AUTH_ID=... PLIVO_AUTH_TOKEN=... \
//     PLIVO_WHATSAPP_SRC=... PLIVO_SMS_SRC=... \
//     WA_TEMPLATE_NAME=otp_login WA_TEMPLATE_LANG=en \
//     SEND_SMS_HOOK_SECRET=v1,whsec_...
// Then in Dashboard → Authentication → Hooks → enable "Send SMS" → point at
// this function.

import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";

const AUTH_ID = Deno.env.get("PLIVO_AUTH_ID")!;
const AUTH_TOKEN = Deno.env.get("PLIVO_AUTH_TOKEN")!;
const WA_SRC = Deno.env.get("PLIVO_WHATSAPP_SRC") ?? "";
const SMS_SRC = Deno.env.get("PLIVO_SMS_SRC") ?? "";
const WA_TEMPLATE = Deno.env.get("WA_TEMPLATE_NAME") ?? "otp";
const WA_LANG = Deno.env.get("WA_TEMPLATE_LANG") ?? "en";
const HOOK_SECRET = Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "";

const PLIVO_URL = `https://api.plivo.com/v1/Account/${AUTH_ID}/Message/`;
const basicAuth = "Basic " + btoa(`${AUTH_ID}:${AUTH_TOKEN}`);

async function plivo(body: Record<string, unknown>): Promise<boolean> {
  const res = await fetch(PLIVO_URL, {
    method: "POST",
    headers: { Authorization: basicAuth, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    console.error("Plivo error", res.status, await res.text());
  }
  return res.ok;
}

async function sendWhatsApp(dst: string, otp: string): Promise<boolean> {
  if (!WA_SRC) return false;
  // Matches the live "otp" template: body with a single {{1}} param (the code),
  // language "en", no button component. Verified delivered via Plivo.
  // If you edit the template to add a copy-code button, add a matching
  // { type: "button", sub_type: "url", index: "0", parameters: [...] } entry.
  return plivo({
    src: WA_SRC,
    dst,
    type: "whatsapp",
    template: {
      name: WA_TEMPLATE,
      language: WA_LANG,
      components: [
        { type: "body", parameters: [{ type: "text", text: otp }] },
      ],
    },
  });
}

async function sendSms(dst: string, otp: string): Promise<boolean> {
  if (!SMS_SRC) return false;
  return plivo({
    src: SMS_SRC,
    dst,
    text: `${otp} is your RentoRent verification code. Valid for 10 minutes.`,
  });
}

Deno.serve(async (req) => {
  const raw = await req.text();

  // Verify the hook came from Supabase (recommended). Skips if no secret set.
  if (HOOK_SECRET) {
    try {
      const wh = new Webhook(HOOK_SECRET.replace("v1,whsec_", ""));
      wh.verify(raw, Object.fromEntries(req.headers));
    } catch (e) {
      console.error("hook verify failed", e);
      return new Response("invalid signature", { status: 401 });
    }
  }

  let dst = "";
  let otp = "";
  try {
    const payload = JSON.parse(raw);
    dst = String(payload?.user?.phone ?? "").replace(/[^0-9]/g, "");
    otp = String(payload?.sms?.otp ?? "");
  } catch (_) {
    return new Response("bad payload", { status: 400 });
  }
  if (!dst || !otp) return new Response("missing phone/otp", { status: 400 });

  const delivered = (await sendWhatsApp(dst, otp)) || (await sendSms(dst, otp));
  if (!delivered) {
    return new Response(JSON.stringify({ error: "delivery failed" }), {
      status: 502,
      headers: { "Content-Type": "application/json" },
    });
  }
  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
