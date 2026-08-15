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

**`API_URL` takes a comma-separated list and the app finds the live one itself.**
On the first request it probes every candidate at once, keeps whichever answers,
and caches it. That is why the shipped default covers all three dev setups:

```
API_URL=http://localhost:8000,http://10.0.2.2:8000,http://192.168.1.10:8000
```

| Candidate | Covers |
|---|---|
| `http://localhost:8000` | desktop and web; a USB phone if you ran `adb reverse tcp:8000 tcp:8000` |
| `http://10.0.2.2:8000` | the Android emulator's alias for the host machine |
| `http://<your-pc-lan-ip>:8000` | a phone on the same Wi-Fi — **edit this one to your own IP** |

Find your LAN IP with `hostname -I` (Linux) or `ipconfig` (Windows). Because the
list is probed rather than trusted, a stale entry costs nothing: it simply loses
the race. When one host stops answering mid-session the app re-probes on the next
request, so moving between Wi-Fi and USB recovers without a restart.

**Always start the server with `--host 0.0.0.0`** — bound to `127.0.0.1` (the
default) it is unreachable from the phone no matter which URL you use:

```bash
uvicorn app.main:app --reload --host 0.0.0.0
```

Confirm from the PC before blaming the phone:

```bash
curl http://<your-pc-lan-ip>:8000/api/     # expect {"message":"QuestBoard API is running!"}
```

If that fails, the phone has no chance — it is a binding or firewall problem.

Once the API is deployed (step 9) a single HTTPS entry replaces the whole list.

### Cleartext HTTP is handled for you

Android 9+ blocks plain `http://` by default, and the request fails *before it
leaves the phone* — which looks exactly like a dead server. Debug builds now ship
a network security config that permits cleartext
(`android/app/src/debug/res/xml/`), while release builds stay HTTPS-only. You do
not need to change anything; just know that **a deployed API must be HTTPS**.

## 9. Deploying the backend to Render

**Render's free tier is the right choice here**: it runs a plain FastAPI process,
deploys from GitHub on push, and gives you HTTPS — which Android requires. Fly.io
needs a card, Vercel/Netlify only run serverless functions, and Railway's free
tier ended. The one real cost is that a free service **sleeps after 15 minutes
idle**, so the first request after a pause takes ~50 seconds.

You do not need this for development — a phone on your Wi-Fi reaches your PC
directly. Deploy when you need the app to work off your network: a demo, a
teammate's phone, or submission. Note that **signup, login and password reset
never touch your backend** (the client calls Supabase directly), so those keep
working regardless.

### 9.1 Commit a pinned requirements file

Render installs from `server/requirements.txt`. Confirm it resolves cleanly:

```bash
cd server && pip install -r requirements.txt
```

### 9.2 Create the Web Service

Push to GitHub, then on [render.com](https://render.com) → **New → Web Service**
→ connect the repo:

| Setting | Value |
|---|---|
| Root directory | `server` |
| Runtime | Python 3 |
| Build command | `pip install -r requirements.txt` |
| Start command | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
| Instance type | Free |
| Health check path | `/api/` |

`--port $PORT` is not optional: Render assigns the port and a hardcoded 8000
fails health checks.

### 9.3 Environment variables

Add these under **Environment** — copy the values from `server/.env`:

| Key | Notes |
|---|---|
| `DATABASE_URL` | The **pooler** string from step 3 (`...pooler.supabase.com:5432`). The direct host is IPv6-only and Render cannot reach it |
| `SUPABASE_URL` | Same as local |
| `SUPABASE_PUBLISHABLE_KEY` | Same as local |
| `CORS_ORIGINS` | Your web **origin** (`https://example.com`), or `*` while testing. This is a browser origin, not a bind address — `0.0.0.0` matches nothing and blocks every web request |
| `AI_BASE_URL` · `AI_API_KEY` · `AI_MODEL` | Optional. A free AI provider for hints — see step 10. Without any of it `POST /api/ai/hint` returns 503 and the client hides the hint button |

### 9.4 Verify before touching the client

```bash
curl https://<your-app>.onrender.com/api/
# {"message":"QuestBoard API is running!"}
```

If this 500s, open the Render logs — it is almost always `DATABASE_URL`.

### 9.5 Point the app at it

In `client/.env` replace the candidate list with the single HTTPS entry:

```
API_URL=https://<your-app>.onrender.com
```

Then **rebuild** — `.env` is a bundled asset, so hot reload will not pick it up:

```bash
cd client && flutter run            # or: flutter build apk --release
```

HTTPS also means the cleartext exemption no longer matters, so release APKs work
with the strict network config unchanged.

### 9.6 Expect the cold start

The first request after 15 idle minutes takes ~50s and the app will show "could
not reach the server" before it wakes. Options: hit `/api/` yourself a minute
before a demo, or point a free uptime pinger (UptimeRobot, 5-minute interval) at
`/api/` on the day. Do not add a background pinger inside the app.

Pinging every ~10 minutes keeps the service awake permanently, which costs about
730 of the free tier's 750 instance-hours a month. That covers **one** always-on
service — a second one will run out partway through the month.

## 10. AI hints (optional, and free)

`POST /api/ai/hint` asks a model for a Socratic nudge. With nothing configured the
endpoint returns 503 and the client hides the hint button entirely, so the rest of
the app is unaffected — leaving this unset is a supported state, not a broken one.

Any endpoint that speaks the OpenAI `/chat/completions` shape works, which is most of
them. **All three options below are free and need no credit card.** Pick one, put the
three values in `server/.env`, and add the same three in Render's **Environment** for
the deployed copy.

**Google Gemini** — the most generous free tier, and the default recommendation:

```
AI_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai
AI_API_KEY=<key from https://aistudio.google.com/apikey>
AI_MODEL=gemini-2.5-flash
```

**Groq** — noticeably faster, smaller daily allowance:

```
AI_BASE_URL=https://api.groq.com/openai/v1
AI_API_KEY=<key from https://console.groq.com/keys>
AI_MODEL=llama-3.3-70b-versatile
```

**OpenRouter** — a router in front of many models; the free ones end in `:free`:

```
AI_BASE_URL=https://openrouter.ai/api/v1
AI_API_KEY=<key from https://openrouter.ai/keys>
AI_MODEL=meta-llama/llama-3.3-70b-instruct:free
```

Switching providers is an `.env` change, not a code change. If a free quota runs out
the endpoint returns 503 with a message saying so, and — because the deduction and the
model call share one transaction — the user is not charged the 5 points.

Verify without opening the app:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8000/api/ai/hint
# {"available":true,"points_cost":5,"hints_remaining":3}
```

`ANTHROPIC_API_KEY` / `ANTHROPIC_MODEL` still work for a paid Anthropic key and are
used only when `AI_API_KEY` is empty, so both can sit in `.env` at once. The
`anthropic` package is imported lazily, so a free-tier deploy never loads it.

Hints cost the *user* 5 points and are capped at 3 per hour per user, which is what
bounds usage whichever provider you pick.

## 11. The daily challenge

Nothing to configure. `GET /api/challenges/today` pulls a rated problem from the
public Codeforces API on the first request of each day and stores it; there is no
cron job and no API key. If Codeforces is down, the endpoint serves the last
challenge it stored and flags it so the screen says so.

Claiming the bonus requires a **verified** Codeforces handle: the user submits a
deliberate compilation error to a problem the server names, and the server looks
for it in their public submission list. That is the ownership proof — a handle
existing says nothing about who typed it into our form.

## 12. Releasing the apps

### 12.1 Point the client at the deployed API

`client/.env` should be a single HTTPS entry — not a candidate list:

```
API_URL=https://<your-app>.onrender.com
```

This is the setting that survives changing Wi-Fi networks, which a LAN address
does not. A release APK also blocks cleartext HTTP outright, so a local
`http://192.168.…` server is unreachable from one no matter what `.env` says.

`.env` is a **bundled asset**: it is read at build time, so changing it means
rebuilding, not hot-reloading.

### 12.2 Android APK — building and sharing it

```bash
cd client
flutter build apk --release --split-per-abi
```

Three APKs land in `build/app/outputs/flutter-apk/`:

| File | Size | Who needs it |
|---|---|---|
| `app-arm64-v8a-release.apk` | ~20 MB | **Every modern phone.** This is the one to share |
| `app-armeabi-v7a-release.apk` | ~18 MB | Older 32-bit devices (roughly pre-2016) |
| `app-x86_64-release.apk` | ~22 MB | Emulators, not real phones |

Copy the one you are sharing somewhere with a name that means something —
`client/dist/` is already gitignored for this:

```bash
mkdir -p dist
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk dist/questboard-arm64.apk
```

If you would rather not think about ABIs at all, plain
`flutter build apk --release` produces a single `app-release.apk` (~55 MB) that
runs everywhere — it is the same app packaged three times. Good for a
"just send me the file" situation, wasteful for anything else.

**How to actually send it.** An APK is one file; the only real obstacle is that
most services refuse the `.apk` extension:

- **Google Drive / OneDrive / Dropbox** — upload, share the link, set it to
  "anyone with the link". Works, and the file stays put.
- **WhatsApp / Telegram** — Telegram sends APKs as-is. WhatsApp allows it as a
  document, but the 100 MB limit means you want the 20 MB split build.
- **Email** — usually blocked. Gmail rejects `.apk` outright. Zip it first, or
  use a link instead.
- **GitHub Releases** — the tidiest option for a group project: tag a release
  and attach the APK. It gives you a permanent URL and a version history, and
  markers can download it without a login.

**What the person installing it has to do.** Android blocks APKs from outside
the Play Store by default, so tell them in advance or they will think it is
broken:

1. Open the file — Android warns "For your security, your phone is not allowed
   to install unknown apps from this source".
2. Tap **Settings** on that prompt, enable **Allow from this source** for
   whichever app they downloaded it with (Chrome, Drive, Files).
3. Go back and tap **Install**. Play Protect may add a "scan this app?" prompt —
   that is normal for any APK it has not seen before.

Two things worth checking on a release build, because debug builds hide both:

- **It is signed with the debug key.** `android/app/build.gradle.kts` still says
  so. That is fine for handing an APK to a marker or a teammate, and unacceptable
  for the Play Store — that needs a real keystore. It also means each rebuild
  from a different machine may not upgrade cleanly over the last one; uninstall
  first if an install is refused.
- **Test the release APK, not the debug one.** The `INTERNET` permission and the
  cleartext policy differ between the two, and both have broken networking here
  before ([TASKS.md](../TASKS.md) — "Fixed after M3 field testing").

The application ID is `io.questboard.app`, matching the `io.questboard://`
deep-link scheme. Changing it after release orphans every existing install.

### 12.3 Web

```bash
cd client
flutter build web
```

`build/web` is a static directory — any static host serves it. On Render:
**New → Static Site**, same repository, root directory `client`, build command
`flutter build web`, publish directory `build/web`.

Two things the web build needs that the phone does not:

- `CORS_ORIGINS` on the API must include the site's origin (or be `*`). A
  browser will not send the request otherwise, and the failure shows up as a
  network error with no server log to match it.
- Add the site URL to Supabase's redirect list (step 5), or email links from a
  browser signup dead-end.

### 12.4 Demo data

```bash
cd server && source .venv/bin/activate
python seed_demo.py          # five students, eight quests, answers, votes
python seed_demo.py --undo   # removes exactly what it created
```

Every point it creates is earned through the normal services, so the ledger
balances and the leaderboard shows numbers somebody actually earned — the script
prints each balance next to its ledger sum so you can see they agree. The demo
accounts are real Supabase logins (`nadia@questboard.test` / `questboard-demo`),
so you can sign in as one while presenting.

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
| Phone cannot reach the API | Check `API_URL` lists your current LAN IP (`hostname -I`), and that uvicorn was started with `--host 0.0.0.0`. `curl http://<lan-ip>:8000/api/` from the PC first. USB alternative: `adb reverse tcp:8000 tcp:8000` |
| App hangs on a blank screen at launch | It no longer can — startup routing gives up after 4s. If it still does, `API_URL` is malformed rather than unreachable |
| Everything works except calls to your own API | Cleartext HTTP blocked. Only affects release builds now; a deployed API must be HTTPS |
| Hints 503 with "not configured" | No `AI_API_KEY` / `AI_BASE_URL` / `AI_MODEL` — step 10. On Render they must be set in **Environment**, not just in your local `.env` |
| Hints 503 with "rejected the request (404)" | `AI_MODEL` is not a model that provider serves. Groq's names differ from OpenRouter's: `llama-3.3-70b-versatile`, not `meta-llama/llama-3.3-70b-instruct:free`. List them with `curl $AI_BASE_URL/models -H "Authorization: Bearer $AI_API_KEY"` |
| A new endpoint 404s on Render but works locally | Render is serving an older commit. Check **Events** for a deploy after your push |
| `pytest` fails with a connection timeout | The tests talk to the real database; that is a network failure, not a test failure. Re-run |
