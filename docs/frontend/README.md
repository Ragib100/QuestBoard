# Frontend

Flutter, in `client/`. One codebase for Android, Linux, Windows and web. It
talks to **Supabase Auth directly** and to FastAPI for everything else.

```bash
cd client
flutter pub get
flutter run -d linux          # or -d chrome, -d windows, -d <android-device-id>

flutter analyze && flutter test   # both must be clean before any PR
```

Start the server first — the client needs it.

## Mobile-first, and that is a rule

This is a phone app that also runs on desktop. Build the phone layout first and
treat the wide layout as the variant:

- Always `isWideLayout(context)` from `core/breakpoints.dart` (900px). **Never a
  width literal of your own** — `test/breakpoints_test.dart` fails the build if
  you write one ([../decisions.md](../decisions.md) D33).
- No fixed widths on anything a phone renders. `Wrap`/`Flexible` over hard
  `Row`s. Full-width buttons. Every screen scrollable.
- Anything the desktop sidebar offers must also be reachable on a phone.
- **If it does not work at 360px wide, it does not work.** New screens get a case
  in `test/mobile_layout_test.dart`, which fails on overflow at 320px and 360px.

## Architecture rules

| Rule | Why |
|---|---|
| `StatefulWidget` + `setState` | No Riverpod, Bloc or Provider. The app is small enough that a state library is a dependency to learn, not a problem solved ([../decisions.md](../decisions.md) D3) |
| `Navigator.push` + `MaterialPageRoute` | No GoRouter. Deep links are handled in `main.dart` by hand |
| `package:http` | No Dio. `ApiClient` wraps it |
| Services are singletons | `AuthService.instance`, private constructors |
| **API calls live in `services/`, never in a widget** | A screen calls a service; a service calls `ApiClient` |
| Colors come from `AppColors` | Never a raw `Color(0xFF...)` in a screen ([../decisions.md](../decisions.md) D13) |
| Durations come from `core/motion.dart` | Never a hardcoded `Duration` in a screen |
| Never render `username` | It holds the signup email. Use `core/display_name.dart` (D36) |

A package that supplies a **platform capability** is a different question and has
been added twice — `url_launcher` (D37) and `webview_flutter` (D43). An
architectural preference is not.

## File map

```
client/lib/
  main.dart                  entry, theme, splash, deep links, bootstrap-after-runApp
  config/supabase_config.dart
  core/                      helpers and shared widgets — see core.md, widgets.md
  models/                    plain data classes, JSON in/out — see services.md
  services/
    api/api_client.dart      base URL probing, bearer token, ApiException
    common/                  one singleton per domain — see services.md
  app/
    intro.dart               the landing page
    dashboard.dart           the shell: 5 tabs, sidebar or bottom nav
    auth/                    login, signup, email_verification, forgot_password,
                             post_login_router
    common/reset_password.dart
    profile/profile_create.dart        post-signup onboarding
    modules/
      questions/             browse, detail, ask
      leaderboard/           screen + podium
      daily_challenge/       today, archive, problem statement
      notifications/
      profile/               screen, edit, codeforces_verify
    admin/                   dashboard, user_management, content_moderation
  test/                      seven suites — see testing.md
```

## Environment

`client/.env`, loaded with `flutter_dotenv`:

| Key | Notes |
|---|---|
| `SUPABASE_URL` | |
| `SUPABASE_PUBLISHABLE_KEY` | |
| `API_URL` | The deployed HTTPS URL |

`API_URL` also accepts a **comma-separated candidate list** for local server
work — the app probes them all in parallel and keeps whichever answers. A LAN
address breaks whenever the network changes and a release APK cannot use one at
all, so plain HTTPS is the default. See
[services.md](services.md#apiclient--servicesapiapi_clientdart).

A missing or incomplete `.env` is a setup problem, not a crash: the app shows
`ConfigurationRequiredScreen` and says what is missing.

## Dependencies

| Package | For |
|---|---|
| `supabase_flutter` | Auth, and direct Storage uploads |
| `http` | Every API call |
| `flutter_dotenv` | `.env` |
| `google_fonts` | Inter + Outfit |
| `app_links` | The `io.questboard://` deep links |
| `email_validator` | Signup and login validation |
| `image_picker` | Avatars |
| `file_picker` | Attaching a source file — returns bytes on every platform, including web |
| `url_launcher` | Opening external links (D37) |
| `webview_flutter` | Hosting Codeforces in-app (D43) |

Dev: `flutter_lints`, `flutter_launcher_icons`.

## Where to read next

- [screens.md](screens.md) — every screen, what it calls, where it goes
- [services.md](services.md) — `ApiClient`, the service singletons, the models
- [core.md](core.md) — breakpoints, time, names, links, the Codeforces WebView,
  the syntax highlighter and re-indenter
- [widgets.md](widgets.md) — everything in `core/widgets/`
- [design-system.md](design-system.md) — colors, type, motion, the four states
- [testing.md](testing.md) — what each suite guards
