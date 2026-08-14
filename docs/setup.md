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

## 4. Email delivery via Brevo

You need your own SMTP provider. **Brevo is a good fit** — 300 emails/day free
forever, no credit card, and no per-domain verification needed to start. That is
far more than this project will ever use.

Supabase needs **SMTP credentials, not Brevo's REST API**, so ignore the API key
section of their docs.

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

## 5. Redirect URLs

The app catches email links through the custom scheme `io.questboard://`. Supabase
refuses to redirect anywhere it has not been told about.

**Authentication → URL Configuration → Redirect URLs**, add both:

```
io.questboard://signup-callback
io.questboard://reset-callback
```

The Android side of this is already wired: `AndroidManifest.xml` declares an
intent filter for the `io.questboard` scheme, so tapping the link opens the app.

> On **desktop and web** the custom scheme will not resolve. Test the email flow
> on Android, or confirm the account manually in **Authentication → Users** while
> developing on desktop.

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

## 8. Pointing the client at the API

`API_URL` in `client/.env` must be reachable **from the device running the app**,
which is not the same as reachable from your PC.

| Running on | `API_URL` |
|---|---|
| Desktop or web on the same PC | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Physical phone on the same Wi-Fi | `http://<your-pc-lan-ip>:8000` |
| Phone anywhere else | your deployed URL (step 9) |

Find your LAN IP with `ip addr` (Linux) or `ipconfig` (Windows). The server must
be started with `--host 0.0.0.0`, and your firewall must allow port 8000.

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
| Email arrives, link does nothing | Redirect URL missing from step 5, or you opened it on desktop/web instead of Android |
| `role "username" does not exist` | `DATABASE_URL` is still the placeholder — step 3 |
| `could not translate host name` / connection timeout | Using the IPv6-only direct host instead of the pooler — step 3 |
| Profile creation fails with 401 | The API cannot verify the token; check `SUPABASE_URL` matches in both `.env` files |
| Flutter web: "XMLHttpRequest error" | `CORS_ORIGINS` does not include your origin, or the API is not running |
| Phone cannot reach the API | Server not started with `--host 0.0.0.0`, wrong LAN IP, or a firewall |
