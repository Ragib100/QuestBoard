# QuestBoard

A gamified Q&A app for STEM students. Post a **quest** with a point bounty, get answers,
accept the best one and the points transfer to whoever helped you.

**Flutter** client · **FastAPI** server · **Supabase** (Postgres, Auth, Storage)

| | |
|---|---|
| Getting it running (Supabase, email, DB) | [docs/setup.md](docs/setup.md) |
| What we're building and why | [docs/product.md](docs/product.md) |
| What's done and what's next | [TASKS.md](TASKS.md) |
| How the pieces fit together | [docs/architecture.md](docs/architecture.md) |
| Database schema | [docs/data-model.md](docs/data-model.md) |
| API contract | [docs/api.md](docs/api.md) |
| UI conventions | [docs/design-system.md](docs/design-system.md) |
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
uvicorn app.main:app --reload          # http://localhost:8000, docs at /docs
```

```bash
cd client
flutter pub get
flutter run -d linux                   # or -d windows, -d chrome
```

## Running the client elsewhere

Set `API_URL` in `client/.env` to match the target, or the app cannot reach the server:

| Target | `API_URL` |
|---|---|
| Desktop / web | `http://localhost:8000` |
| Android emulator | `http://10.0.2.2:8000` |
| Physical phone | `http://<your-pc-lan-ip>:8000` |

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
endpoint in `docs/api.md` before building the screen that consumes it, and update
[TASKS.md](TASKS.md) in the same PR as the work.
