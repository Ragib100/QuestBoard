# QuestBoard

A gamified Q&A app for STEM students. Post a **quest** with a point bounty, get answers,
accept the best one and the points transfer to whoever helped you.

**Flutter** client · **FastAPI** server · **Supabase** (Postgres, Auth, Storage)

Full documentation index: **[docs/README.md](docs/README.md)** — split into
[`docs/backend/`](docs/backend/README.md),
[`docs/frontend/`](docs/frontend/README.md) and
[`docs/db/`](docs/db/README.md), with the cross-cutting documents at the top
level.

| | |
|---|---|
| Getting it running (Supabase, email, DB) | [docs/setup.md](docs/setup.md) |
| What we're building and why | [docs/product.md](docs/product.md) |
| What's done and what's next | [TASKS.md](TASKS.md) |
| How the pieces fit together | [docs/architecture.md](docs/architecture.md) |
| API contract | [docs/backend/api.md](docs/backend/api.md) |
| Server internals — routers, services, models | [docs/backend/](docs/backend/README.md) |
| Client internals — screens, services, widgets | [docs/frontend/](docs/frontend/README.md) |
| Database schema and the point ledger | [docs/db/](docs/db/README.md) |
| UI conventions | [docs/frontend/design-system.md](docs/frontend/design-system.md) |
| Why something is the way it is | [docs/decisions.md](docs/decisions.md) |

## Setup

**First time? Follow [docs/setup.md](docs/setup.md).** It covers the Supabase
project, creating the tables, email delivery, and the deep-link configuration —
none of which are optional for the app to work.

Once configured, copy `server/.env.example` → `server/.env` and
`client/.env.example` → `client/.env` and fill in your values.

**Start the server first** — the client needs it running.

```bash
cd server
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --reload --host 0.0.0.0          # http://localhost:8000, docs at /docs
```

```bash
cd client
flutter pub get
flutter run -d linux                   # or -d windows, -d chrome
```

## Running the client elsewhere

`API_URL` in `client/.env` is normally the **deployed HTTPS URL**, and that is the
default — a LAN address breaks whenever the network changes, and a release APK
cannot use one at all.

For local server work it also accepts a **comma-separated candidate list**: the
app probes them all at once and keeps whichever answers, so one `.env` works from
a desktop, an emulator and a phone without editing.

```
API_URL=http://localhost:8000,http://10.0.2.2:8000,http://192.168.0.14:8000
```

| Target | Candidate |
|---|---|
| Desktop / web | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Phone over USB (with `adb reverse`) | `http://localhost:8000` |
| Phone on the same Wi-Fi | `http://<your-pc-lan-ip>:8000` |

Bind uvicorn to `0.0.0.0`, not the default `127.0.0.1`, or a phone can never
reach it.

**Web:** `flutter run -d chrome`, or `flutter run -d web-server` and open the printed
localhost URL in any browser.

**Physical Android device** — the lightest option on a low-end PC, since it uses none of
your RAM. Enable Developer Options (tap *Build Number* seven times in *Settings → About
Phone*), turn on **USB debugging**, plug in over USB and accept the prompt. Confirm with
`flutter devices`, then `flutter run`.

**Emulator**, if you have no device to hand — the AOSP ATD image is the lightest:

```bash
sdkmanager "system-images;android-30;aosp_atd;x86_64"
avdmanager create avd -n ATD_Device -k "system-images;android-30;aosp_atd;x86_64"
emulator -avd ATD_Device
```

## Contributing

Feature branches only; `main` stays deployable. Every PR needs one review. Define the
endpoint in `docs/backend/api.md` before building the screen that consumes it, and update
[TASKS.md](TASKS.md) in the same PR as the work.
