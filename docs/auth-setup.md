# Going live with real auth (Google + Plivo OTP)

The app ships with a **flag** so nothing changes until you're ready:

- `mobile/lib/core/auth/auth_config.dart` → `useRealAuth` (default **false** = mock OTP `123456`).
- Turn it on by building/running with `--dart-define=USE_REAL_AUTH=true` (keep your
  existing `--dart-define-from-file=env.json` too).

Everything below is **dashboard / provider configuration** — no app-code changes needed.

---

## 1. Google Sign-In (OAuth redirect flow)

Uses one **web** OAuth client — works on web and Android without the native SDK.

1. **Google Cloud Console** → create/choose a project → *APIs & Services → OAuth consent screen* (External, add your support email + app name).
2. *Credentials → Create credentials → OAuth client ID → Web application*:
   - **Authorized redirect URI**: `https://<your-project-ref>.supabase.co/auth/v1/callback`
   - Copy the **Client ID** and **Client secret**.
3. **Supabase Dashboard → Authentication → Providers → Google** → enable → paste Client ID + secret → save.
4. **Supabase → Authentication → URL Configuration → Redirect URLs** — add:
   - Web: your site origin, e.g. `http://127.0.0.1:8080` (dev) and your prod URL.
   - Mobile: `com.realestate.homevista://login-callback` (already registered in `AndroidManifest.xml`).
5. (Native Android account picker later, optional) add an **Android** OAuth client with the app's package name + debug/release **SHA-1**, and switch to `google_sign_in` + `signInWithIdToken`. Not required for launch.

Get the debug SHA-1 if you want the native flow later:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

## 2. Phone OTP delivered by Plivo (WhatsApp + SMS fallback)

Supabase generates & verifies the code; Plivo only delivers it, via the **Send SMS hook**.

1. **Enable phone auth**: Supabase → Authentication → Providers → **Phone** → toggle on. (Leave the built-in SMS provider blank — the hook overrides delivery.)
2. **WhatsApp (recommended, no DLT):** in Plivo, link your **WhatsApp Business Account**, register the sender number, and get an **"authentication" category template** approved by Meta (e.g. `otp_login`). Note the template name + language.
3. **SMS fallback (India):** register a **DLT** sender ID + transactional template on the Jio/Airtel/VI DLT portal; add the sender in Plivo.
4. **Deploy the edge function** (already in `supabase/functions/send-otp`):
   ```bash
   supabase functions deploy send-otp --no-verify-jwt
   supabase secrets set \
     PLIVO_AUTH_ID=xxxx PLIVO_AUTH_TOKEN=xxxx \
     PLIVO_WHATSAPP_SRC=+91xxxxxxxxxx PLIVO_SMS_SRC=HOMEVISTA \
     WA_TEMPLATE_NAME=otp_login WA_TEMPLATE_LANG=en \
     SEND_SMS_HOOK_SECRET=v1,whsec_xxxxx
   ```
5. **Wire the hook**: Supabase → Authentication → **Hooks** → *Send SMS* → enable → select the `send-otp` function. Copy its signing secret into `SEND_SMS_HOOK_SECRET` above.
6. Adjust the `template.components` in `send-otp/index.ts` to match your approved template's body/button params.

## 3. Flip it on

```bash
flutter run --dart-define-from-file=env.json --dart-define=USE_REAL_AUTH=true
# or for release:
flutter build apk --release --dart-define-from-file=env.json --dart-define=USE_REAL_AUTH=true
```

The sign-in screen's "Continue with Mobile" now calls Supabase (Plivo delivers the code),
"Continue with Google" runs OAuth, and the OTP screen verifies against Supabase — the
wrong-code shake still works.

## 4. Still to do at go-live (coupled, not done yet)

- **RLS hardening**: replace the dev-permissive `using(true)` policies with `auth.uid()`-based
  ones, and switch owner posting from the demo owner UUID to the signed-in user's `auth.uid()`.
  (Left untouched on purpose so the mock demo keeps working — see the `production-standard` memory.)
- **Profile source of truth**: role/name/email currently come from local `MockAuth`. Point them at
  `profiles_home` once real sessions exist.
- **Splash / onboarding gating**: refine the splash + onboarding redirect for real sessions
  (the router guard currently sends signed-in users to `/home`).
- **Owner contact number**: see the `owner-contact-phone` memory — wire real owner phones once
  profiles are readable under the hardened RLS.
