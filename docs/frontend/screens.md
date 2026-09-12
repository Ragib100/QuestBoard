# Screens

Every screen in `client/lib/app/`, what it shows, which service it calls and
where it can go next. Line counts are from the files themselves.

## Entry and shell

### `main.dart` — 520 lines

`main()` calls `runApp` **first** and bootstraps **second**
([../decisions.md](../decisions.md) D42). `dotenv.load` reads a file and
`Supabase.initialize` restores the stored session — usually refreshing an
expired token over the network. Awaiting both before `runApp` held the
*operating system's* splash for all of it, so the app looked frozen on something
we do not control and cannot put a progress bar on. Now our own splash paints on
the first frame and the wait happens behind it.

| Piece | Does |
|---|---|
| `MyApp` | Holds the bootstrap future, the `AppLinks` listener and the navigator key. `isSupabaseConfigured` is a test-only override |
| `_buildTheme()` | The whole widget theme — colors from `AppColors`, the 56/38/28/24/20/18 Outfit + 16/14/13/12 Inter type scale |
| `_Launch` | Decides intro vs. dashboard once the bootstrap resolves |
| `_SplashView` | What paints on frame 1 |
| `ConfigurationRequiredScreen` | Shown when `.env` is missing or incomplete — an honest setup message, not a crash |

**Deep links** are matched on scheme `io.questboard`:

- `signup-callback` → `ProfileCreate` (after a 300ms delay, so Supabase has
  parsed the link and the session exists).
- `reset-callback` is deliberately **not** handled here. `supabase_flutter`
  parses the recovery link itself and only then emits
  `AuthChangeEvent.passwordRecovery`; `_watchAuth` navigates on that event.
  Navigating on a timer instead raced that work and landed on the form with no
  session, failing with "Auth session missing".

### `app/intro.dart` — 309 lines

The landing page. No session required, no network call, **no invented
statistics** (ground rule 4). `BrandArt` draws the decorative mark locally with a
`CustomPainter` — an earlier version used remote SVGs via `Image.network`, which
Flutter cannot decode without `flutter_svg`, so they fell through to the
`errorBuilder` on every platform, every time.

Caps its sections rather than the page (D35) and keeps one alignment axis on a
phone (D39). Always offers a way to log in — `test/layout_test.dart` asserts it.

### `app/dashboard.dart` — 1127 lines

The shell. An `IndexedStack` of five tabs inside a `TabTransition`, capped at
`maxWidth: 1400`.

| Index | Tab | Screen |
|---|---|---|
| 0 | Home | `UserHome` (in this file) |
| 1 | Quests | `BrowseQuestions` |
| 2 | Ranks | `LeaderboardScreen` |
| 3 | Daily | `DailyChallengeScreen` |
| 4 | Profile | `ProfileScreen` |

An `IndexedStack` rather than an `AnimatedSwitcher` keyed on the index: the
latter would cross-fade identically but rebuild every tab from scratch on each
tap, re-firing their loads and losing scroll position.

- **Phone**: `AppBar` (title, `PointsBadge`, `_NotificationBell`, overflow menu)
  + five-tab bottom bar. The bottom bar is the phone shell's only chrome, so
  everything the desktop sidebar offers has to live in that menu or be
  unreachable.
- **Desktop**: sidebar + top bar.
- `_SuspendedBanner` sits above the stack when `is_suspended`.
- The daily challenge is a **tab, not an overflow-menu item** (D32).

Calls `UserService.me`, `QuestService.list`, `GamificationService.leaderboard`,
`badgesFor` and `unreadCount`; `AuthService.logout`.

The admin entry appears in the menu only when the profile has `is_admin` —
showing it to a normal user would only ever disappoint, since every endpoint
behind it 403s.

## Auth

### `auth/login.dart` — 211 lines
Email + password via `AuthService.login`. Rejects a malformed email and an empty
password **before** calling the API. Offers routes to signup and password reset.

### `auth/signup.dart` — 235 lines
`AuthService.signUp`. The register button is disabled until the terms checkbox is
ticked. Validates email format, password length and confirmation match. Reports
"already registered" rather than Supabase's silent fake success.

### `auth/email_verification.dart` — 114 lines
Where signup lands. The account exists but is unverified until the emailed link
is opened, which deep-links back into `ProfileCreate`.
`AuthService.resendVerification`.

### `auth/forgot_password.dart` — 143 lines
`AuthService.forgotPassword`. Rejects a malformed email locally.

### `common/reset_password.dart` — 113 lines
Reached **only** via the `passwordRecovery` auth event. Calls
`AuthService.updatePassword`.

### `auth/post_login_router.dart` — 37 lines

Not a screen — the function that decides where a signed-in user belongs.

```dart
landingScreenForCurrentUser() → Dashboard | ProfileCreate
goToLanding(context)          → replaces the whole stack
```

Verifying an email creates the Supabase account but **not** the `users` row —
that happens in `ProfileCreate`. Anyone who quits mid-onboarding, or signs in on
a new device before finishing, has a valid session and no profile, so every entry
point asks the API rather than assuming the dashboard. A `404` from
`GET /users/me` means onboarding.

An offline failure returns `Dashboard`, deliberately: the dashboard degrades into
empty states, whereas sending a fully onboarded user back through signup would
not. **Startup never blocks on this call** — it uses `ApiClient.fastTimeout`.

### `profile/profile_create.dart` — 127 lines
Post-signup onboarding: username, names, phone, avatar, Codeforces handle.
`UserService.createUser`, which is what pays the 100-point signup bonus.

## Quests

### `modules/questions/browse_questions.dart` — 450 lines
The feed. `QuestService.list` with infinite scroll (`_page + 1`), pull to
refresh, tag chips (14 tags), and `sort = latest | bounty | votes`. Search runs
through `SearchField`, which owns a 350ms debounce. `QuestTile` is public and
layout-only so `mobile_layout_test.dart` can pump it.

### `modules/questions/question_detail.dart` — 712 lines
One quest with its answers, accepted first then by score.

| Action | Call |
|---|---|
| Load | `QuestService.get` |
| Vote a quest / an answer | `voteQuest` / `voteAnswer` — optimistic, rolled back on failure (D16) |
| Answer | `QuestService.answer(questId, body, submission:)` |
| Accept | `QuestService.accept`, behind a confirmation dialog |
| AI hint | `HintService.status` then `HintService.forQuest` |

The answer composer is hidden from the quest author and on solved quests, and
keeps its `CodeComposer` collapsed until it is wanted. An answer's attachment
renders as an `AttachmentChip`; its code as a `CodeBlock`.

The hint button reads `HintService.status` first, so it can say what a hint costs
before anyone spends anything — and hides entirely when the server reports no
provider.

### `modules/questions/ask_question.dart` — 375 lines
Post form. `UserService.getProfile` first, so the bounty slider can be capped at
the author's **real** balance (`_maxBounty = 100`, `_maxTags = 5`). Then
`QuestService.create`.

## Gamification

### `modules/leaderboard/leaderboard_screen.dart` — 248 lines
`GamificationService.leaderboard` for `weekly` and `all_time`, with the caller's
own rank pinned.

### `modules/leaderboard/leaderboard_podium.dart` — 206 lines
The top three on a podium, replacing the 🥇🥈🥉 emoji that used to sit in a rank
column. Public and layout-only — it takes its data as arguments, like
`DailyChallengeView` and `AdminDashboardView`, so the layout tests can pump it
without a session.

The pedestals **look** like they break the no-animated-layout rule and do not:
they are laid out at full height from frame 0 and only *drawn* growing, via a
`scaleY` transform. The first version tweened the height inside a fixed-height
box, passed the widget test, and overflowed in real use (D25).

### `modules/notifications/notifications_screen.dart` — 230 lines
`GamificationService.notifications`, `markRead`, `markAllRead`. Four types
arrive; votes deliberately never notify (D19).

## Daily challenge

### `modules/daily_challenge/daily_challenge_screen.dart` — 1357 lines

The largest screen. `ChallengeService.today` / `detail` / `leaderboard`.

The solve is not taken on trust: claiming asks the server to check the user's
public Codeforces submissions for an accepted verdict on this exact problem,
which is why the handle has to be verified first. Submitting code in the app does
not change that; it records the work, it does not prove it.

| Piece | Does |
|---|---|
| `DailyChallengeView` | Public, layout-only, testable without a session |
| `ChallengeActionBar` | The pinned bar. **One primary action at a time** (D48) |
| `verdictChecks = 6` | How many times an in-app submit polls Codeforces for its verdict, four seconds apart. Shared with the bar so the progress indicator and the loop cannot drift |
| `ExternalLink` / `_StatementLink` | Route through `openCodeforces()` |

The claim rules are stated **before** the button rather than discovered through a
failed claim.

### `modules/daily_challenge/past_challenges_screen.dart` — 348 lines
The archive: every past challenge, still solvable. `ChallengeService.archive`.

The point of the screen is the **decay**, so every row leads with what it pays
*now* and says what it was worth on its day. Showing the original bounty alone
would advertise a number the server will not pay. `_DecayExplainer` spells out
the schedule.

### `modules/daily_challenge/problem_statement_screen.dart` — 657 lines

The real Codeforces statement, rendered inside QuestBoard.

The statement arrives as sanitised HTML — Codeforces publishes maths as
`$$$...$$$` for MathJax, plus images, tables and pre-formatted samples, and
flattening that into a `Text` widget would lose the half of a statement that
carries the meaning. So it is drawn in a WebView under `statementCss`, our own
stylesheet, which is what makes it look like part of the app (D45).

Two sources, tried in order:

1. **The server's cached scrape** — `ChallengeService.statement`. Fast,
   sanitised, shared by everyone.
2. **`_renderLive`** — when that returns `available: false`, which on the
   deployed API is the usual answer for a problem nobody has opened yet, the
   device reads Codeforces' own page itself via `statementReaderScript`. That
   WebView deliberately opens **no JavaScript channel** into the app (D47).

Both end up drawn with the same stylesheet, so which one ran is not something the
reader can tell. Where there is no WebView — the Linux and Windows builds —
the content degrades to stripped text plus native sample blocks. That is worse,
and the screen is honest about being worse.

## Profile

### `modules/profile/profile_screen.dart` — 598 lines
`UserService.me` / `getProfile` / `points`, and `GamificationService.badgesFor`.
Shows the avatar (via `UserService.avatarUrl`), balance, streak, badges and the
point ledger.

Locked badges stay visible with their condition printed underneath, because
`badges.description` **is** the condition and it is the only copy of it (D21,
D50). The earned/spent figures cover exactly the rows it fetched — the profile
asks for 10 — and say so.

### `modules/profile/profile_edit.dart` — 224 lines
`UserService.updateProfile`, `uploadAvatar`. The fields mirror the `users` table
exactly — there is no `bio` column, so there is no bio field. Changing the
Codeforces handle clears verification.

### `modules/profile/codeforces_verify.dart` — 247 lines
Proves the handle on a profile belongs to the person holding it.

Reading a handle back from the Codeforces API only shows the handle exists. Only
the account's owner can put a **submission** on it, so the server names a problem
and asks for a deliberate compilation error — harmless, unambiguous, checkable.
`ChallengeService.verificationChallenge` then `confirmVerification`; pops `true`
once the server accepts.

Verifying gates **claiming**, not saving (D40).

## Admin

All three are reachable only from the overflow menu / sidebar, and only when the
profile has `is_admin`. Every endpoint behind them 403s for anyone else, so the
gate is defence in depth rather than the actual protection.

### `admin/admin_dashboard.dart` — 300 lines
`AdminService.stats`. `AdminDashboardView` is public and layout-only.

### `admin/user_management.dart` — 290 lines
`AdminService.users` (paginated, searchable) and `setSuspended`. Suspension is
explicit, not a toggle.

### `admin/content_moderation.dart` — 228 lines
`QuestService.list` + `AdminService.deleteQuest`.

There are **no "flagged" tabs**, because there is no reporting feature — nothing
in the app lets a user flag anything, so a review queue would always be empty and
would imply a workflow that does not exist. This lists the real feed, searchable,
with the one moderation action the API actually has (D23).
