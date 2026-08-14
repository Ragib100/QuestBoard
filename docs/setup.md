# Setup

Getting QuestBoard running from an empty machine. Follow the steps in order —
each one depends on the one before it. Budget 30–40 minutes the first time.

> **Why your emails are not arriving:** Supabase's built-in email service only
> delivers to addresses belonging to your project's team members, and caps you at
> a couple of messages per hour. It is a demo service, not a mail provider. Any
> other address is silently dropped — no error, no email. Step 4 fixes this
> permanently. It is also why login then says "invalid credentials": the account
> exists but was never confirmed, and Supabase refuses unconfirmed logins.

---

## 1. Supabase project

Create a project at [supabase.com](https://supabase.com) (the free tier is
enough). Save the database password it shows you — it is displayed once and you
need it in step 3.

From **Project Settings → Data API**, copy:

- **Project URL** → `SUPABASE_URL`
- **anon / publishable key** → `SUPABASE_PUBLISHABLE_KEY`

Both the client and the server use these two values.

## 2. Create the tables

Open **SQL Editor → New query**, paste the whole of
[`server/schema.sql`](../server/schema.sql), and run it. It creates `users` and
`quests`, an `updated_at` trigger, and the row-level-security policies.

Then create the storage bucket for avatars — **Storage → New bucket**:

| Setting | Value |
|---|---|
| Name | `profile_image` |
| Public bucket | **on** (the app builds public URLs for avatars) |

## 3. Database connection string

**Project Settings → Database → Connection string → Session pooler.**

Take the URI and change two things: swap `postgresql://` for
`postgresql+psycopg://`, and replace `[YOUR-PASSWORD]` with the password from
step 1. The result goes in `server/.env` as `DATABASE_URL`:

```
postgresql+psycopg://postgres.abcdefgh:YourPassword@aws-0-ap-south-1.pooler.supabase.com:5432/postgres
```

Two traps worth knowing:

- **Use the pooler host**, not `db.<ref>.supabase.co`. The direct host is
  IPv6-only, and most home ISPs and Render's free tier cannot reach it.
- **Use port 5432** (session mode). Port 6543 is transaction mode, which does not
  support the prepared statements SQLAlchemy relies on.

If your password contains `@ : / ?` or `#`, percent-encode it.

## 4. Email delivery (custom SMTP)

You need your own SMTP provider — Supabase's built-in mailer only reaches your own
team members. Any provider works; Supabase wants **SMTP credentials, not a REST
API key**, so ignore the "API" section of whichever provider you pick.

- **Resend** — Supabase has a one-click integration; the free tier covers 3,000
  emails/month. Sending from their shared `onboarding@resend.dev` sender works
  immediately with no domain setup.
- **Brevo** — 300 emails/day free, no domain verification needed to start.

Either is far more than this project will use. Steps below are for Brevo; Resend
follows the same shape (host `smtp.resend.com`, port `587`, username `resend`,
password = your API key).

1. Sign up at [brevo.com](https://www.brevo.com) and verify your own email.
2. Go to **Senders, Domains & Dedicated IPs → Senders** and add a sender address
   you control (your Gmail is fine). Confirm the email Brevo sends you.
3. Go to **SMTP & API → SMTP**. Note the server, port, login, and generate a
   **master password** (this is your SMTP key — not your account password).
4. In Supabase: **Project Settings → Authentication → SMTP Settings**, enable
   *Custom SMTP*, and fill in:

   | Field | Value |
   |---|---|
   | Sender email | the address you verified in step 2 |
   | Sender name | `QuestBoard` |
   | Host | `smtp-relay.brevo.com` |
   | Port | `587` |
   | Username | the SMTP login Brevo shows (looks like `8xxxxx001@smtp-brevo.com`) |
   | Password | the SMTP master password from step 3 |

5. Save, then raise the rate limit: **Authentication → Rate Limits → emails per
   hour**. The default of 2 is a Supabase safety net, not a Brevo limit.

**The sender address must be the verified Brevo sender.** A mismatch is the most
common cause of mail that silently fails after this is configured.

## 5. Redirect URLs — where broken email links come from

**If your verification or reset link lands on a blank / "cannot be reached" page,
this step is the reason.** Supabase only redirects to URLs on its allow-list. When
the requested address is not on it, Supabase silently falls back to your **Site
URL**, which defaults to `http://localhost:3000` — a server you are not running.
That is the "unknown area that doesn't load".

Go to **Authentication → URL Configuration** and set both:

**Redirect URLs** — add each on its own line:

```
io.questboard://signup-callback
io.questboard://reset-callback
```

**Site URL** — set it to `io.questboard://signup-callback` too. It is the fallback
for any link that misses the allow-list, so pointing it at the app means even a
stale email opens something real instead of a dead localhost page.

Then **rebuild the Android app** (`flutter run` again, not hot reload).
`AndroidManifest.xml` now declares an intent filter for the `io.questboard`
scheme, but a manifest change only takes effect on a fresh install.

> **The custom scheme only resolves on Android.** A browser on desktop or web has
> no idea what `io.questboard://` means and will show an error page no matter how
> Supabase is configured — that is expected, not a bug. Test the email flow on a
> phone or emulator. While developing on desktop, confirm accounts by hand in
> **Authentication → Users**.

## 6. Environment files

```bash
cp server/.env.example server/.env      # fill in DATABASE_URL + the two Supabase values
cp client/.env.example client/.env      # fill in the two Supabase values + API_URL
```

`API_URL` depends on where the client runs — see the table in step 8.

## 7. Run it

```bash
cd server
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0    # 0.0.0.0 so your phone can reach it
```

Check <http://localhost:8000/api/> — you should get
`{"message": "QuestBoard API is running!"}`. Interactive docs are at
<http://localhost:8000/docs>.

```bash
cd client
flutter pub get
flutter run -d chrome        # or -d linux, or a connected phone
```

## 8. Connecting a phone to your API

**Use `adb reverse`.** It is the most reliable option for a USB-connected Android
device and needs no IP address at all:

```bash
adb reverse tcp:8000 tcp:8000     # run once per USB connection
flutter run
```

This tunnels `localhost:8000` *on the phone* to port 8000 on your PC, so
`API_URL=http://localhost:8000` just works — no LAN IP to look up, nothing to
change when your network does, and no firewall involvement. Re-run the command
after unplugging or rebooting the phone.

Other targets:

| Running on | `API_URL` |
|---|---|
| Phone over USB (recommended) | `http://localhost:8000` + `adb reverse` |
| Desktop or web on the same PC | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Phone on the same Wi-Fi, no USB | `http://<your-pc-lan-ip>:8000` |
| Phone anywhere else | your deployed URL (step 9) |

For the Wi-Fi option, find your LAN IP with `ip addr` (Linux) or `ipconfig`
(Windows) — and check it every time, because DHCP reassigns it. Start the server
with `--host 0.0.0.0`, and confirm from the PC first:

```bash
curl http://<your-pc-lan-ip>:8000/api/
```

If that fails, the phone has no chance; it is a firewall or binding problem.

### Cleartext HTTP is handled for you

Android 9+ blocks plain `http://` by default, and the request fails *before it
leaves the phone* — which looks exactly like a dead server. Debug builds now ship
a network security config that permits cleartext
(`android/app/src/debug/res/xml/`), while release builds stay HTTPS-only. You do
not need to change anything; just know that **a deployed API must be HTTPS**.

## 9. Do you need to deploy the backend?

**Not for development.** A phone on the same Wi-Fi as your PC talks to it
directly over the LAN IP. Note that **signup, login and password reset do not
involve your backend at all** — the app calls Supabase directly — so those work
whether or not the API is running. Only profile creation and quests need it.

**Yes for anything else:** demoing off your network, letting a teammate use the
app, installing an APK on someone else's phone, or your final submission. Nobody
can reach `192.168.x.x` from outside your Wi-Fi.

When that time comes, deploy to [Render](https://render.com) as a Web Service:

| Setting | Value |
|---|---|
| Root directory | `server` |
| Build command | `pip install -r requirements.txt` |
| Start command | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
| Environment | `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `CORS_ORIGINS` |

Then set `API_URL` in `client/.env` to the Render URL and rebuild the app. Two
things to expect on the free tier: it sleeps after 15 minutes idle, so the first
request takes ~50 seconds, and you must use the pooler connection string from
step 3. Deploying is tracked as an M6 task — do not do it until the quest loop
works locally.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| No verification email | Custom SMTP not configured — step 4 |
| "Invalid login credentials" right after signing up | The account exists but is unconfirmed. Confirm via the email, or flip the user to confirmed in **Authentication → Users** |
| Link opens a blank or "site cannot be reached" page | Redirect URLs / Site URL not set — step 5. Supabase fell back to `localhost:3000` |
| Link looks right but the app never opens | Manifest intent filter needs a full rebuild, or you opened it on desktop/web where `io.questboard://` cannot resolve |
| "Check your inbox" but no mail, for an email you used before | Fixed in the app: signup now reports "already registered". Supabase itself returns a fake success to prevent email enumeration |
| `role "username" does not exist` | `DATABASE_URL` is still the placeholder — step 3 |
| `could not translate host name` / connection timeout | Using the IPv6-only direct host instead of the pooler — step 3 |
| Profile creation fails with 401 | The API cannot verify the token; check `SUPABASE_URL` matches in both `.env` files |
| Flutter web: "XMLHttpRequest error" | `CORS_ORIGINS` does not include your origin, or the API is not running |
| Phone cannot reach the API | Run `adb reverse tcp:8000 tcp:8000` and set `API_URL=http://localhost:8000`. Otherwise: server not started with `--host 0.0.0.0`, a stale LAN IP, or a firewall |
| App hangs on a blank screen at launch | It no longer can — startup routing gives up after 4s. If it still does, `API_URL` is malformed rather than unreachable |
| Everything works except calls to your own API | Cleartext HTTP blocked. Only affects release builds now; a deployed API must be HTTPS |
