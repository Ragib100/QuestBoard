# Client tests

```bash
cd client
flutter analyze && flutter test    # both must be clean before any PR
```

Seven suites in `client/test/`. They are pure widget and unit tests — no
network, no Supabase session, no device.

| File | Lines | Guards |
|---|---|---|
| `mobile_layout_test.dart` | 989 | **Nothing overflows on a phone** |
| `widget_test.dart` | 369 | Configuration screen, form widgets, display names, statement fallbacks |
| `code_format_test.dart` | 277 | The re-indenter and the highlighter |
| `auth_test.dart` | 140 | Client-side validation before any API call |
| `layout_test.dart` | 151 | Landing page and shared widgets at both extremes |
| `breakpoints_test.dart` | 84 | One breakpoint, in one place |
| `app_time_test.dart` | 80 | Server timestamps are read as UTC and rendered in Dhaka |

## `mobile_layout_test.dart` — the one that matters

Pumps screens at **320px and 360px** and fails on any overflow. **A new screen
gets a case here**; that is the rule in `CLAUDE.md`, not a suggestion.

It covers: standalone screens · a quest tile under hostile content · points
badges in a narrow row · the leaderboard podium **at every text scale 1.0–2.0**
· the five-tab bottom bar · the daily challenge in every state · the embedded
challenge · the pinned claim bar (including that it does not overlap content) ·
one primary action per stage on the action bar · an archived challenge not
claiming Codeforces is down · the Codeforces verification sheet · all three admin
screens · a past-challenge tile · a code block with an unbreakable line · the
code editor and attachment chip · the editor's save button · an unverified user
still getting the editor · the solution editor above the claim rules · an
offline failure retrying itself · a server refusal still being an error, not a
spinner · the answer composer keeping its editor collapsed · an archived
challenge with a saved solution · a large system font scale.

Two habits it enforces:

- **Widgets that take their data as arguments.** `DailyChallengeView`,
  `LeaderboardPodium`, `AdminDashboardView`, `QuestTile` and
  `ChallengeActionBar` are all public and layout-only precisely so this file can
  pump them without a session or a network call.
- **`pumpAndSettle()` before asserting.** A single `pump()` measures frame 0,
  which for an entry animation is the state nobody ever sees.

It is also why animations may not touch layout: this file measures one frame, so
an animated height would have it measuring a layout that never appears on screen
([design-system.md](design-system.md#motion)).

## `breakpoints_test.dart`

Two kinds of assertion:

1. `isWideLayout` is the documented 900px, on both sides of the boundary.
2. **No screen hardcodes its own width breakpoint** — it reads the source and
   fails if one does. That check exists because the dashboard and its tabs once
   disagreed by 60px ([../decisions.md](../decisions.md) D33).

Plus two landing-page layout cases: the section band reaches both window edges,
and the page keeps one alignment axis on a phone (D39).

## `app_time_test.dart`

| Group | Asserts |
|---|---|
| `parseServerTime` | An unzoned server timestamp is read as **UTC, not local** · an explicit zone is left alone · nothing in, null out — no invented time |
| Dhaka rendering | An instant renders on the Bangladesh calendar day · noon and midnight are am/pm correct · a calendar day is **not** shifted |
| `timeAgo` | Compares instants, so the phone's timezone does not matter · a clock slightly behind the server reads "just now", not "-1m ago" |

## `code_format_test.dart`

The largest non-layout suite, in four groups:

- **Brackets** — C++ nests four spaces and keeps `#` in column 0 · a closing
  brace lines up with the line that opened it · `} else {` keeps both halves
  outer · `switch` puts `case` one level in and its body one deeper · an unbraced
  `if` indents only the statement under it · a brace on its own line stays with
  its statement · Dart and JS indent two, Go uses tabs · PHP indents four and
  leaves the open tag alone · **a brace inside a string or a comment does not
  open a block** · wrapped arguments get one level and the closing paren none ·
  already-formatted code reports no change · trailing whitespace goes away.
- **Python** — odd indent widths normalise to four-space steps · a
  triple-quoted body is left exactly as written · continuation lines inside
  brackets get one extra level.
- **Keyword languages** — Ruby closes on `end` and indents two (and a one-liner
  with its own `end` is not a block) · Bash indents between `then`/`fi` and
  `do`/`done`.
- **The editor** — `Fix indent` re-indents the field · `Indent` shifts the
  selected lines rather than moving the caret by a space · **Tab indents instead
  of moving focus**.
- **Highlighting** — keywords, strings, numbers and comments are told apart · an
  unterminated string stops at the newline · SQL keywords match in either case ·
  plain text is one span and no tokens · every line of a block gets a span,
  including empty ones.

## `auth_test.dart`

Login rejects a malformed email and an empty password **before calling the API**,
and offers routes to signup and reset. Signup keeps the register button disabled
until terms are accepted, and rejects a short password and a mismatched
confirmation. Forgot-password rejects a malformed email.

## `widget_test.dart`

- The configuration screen appears when Supabase is not set up (via the
  `isSupabaseConfigured` test override — the one way to reach it without a
  missing `.env` on disk).
- The landing page shows both entry points **and no invented stats**.
- `LabeledField`: label, helper and hint render · passwords are obscured and
  single-line · they can be revealed and hidden again · non-password fields get
  no toggle · input is capped without showing a counter · a required warning
  appears under the field.
- `SearchField` fires once per pause, not per keystroke, and clears immediately.
- **Display names never show an email address** — an email username is trimmed
  to its handle, a real name always wins, a plain handle is left alone, and the
  model getters go through the helper.
- Statement text fallback: maths becomes readable instead of raw TeX · an unknown
  macro loses its backslash rather than shouting it · a superscript with no glyph
  keeps its ASCII form · block tags become line breaks · the worked examples are
  dropped but the note is kept.
- The live statement reader: both render paths use the same stylesheet · **it
  opens no bridge into the app** · it keeps the limits and drops the title · it
  gives up rather than rewriting a Cloudflare page.

## `layout_test.dart`

The landing page and auth screens at 320px and at desktop width; empty and error
states on a small phone; a four-digit points badge not blowing out its row; the
vote control in both orientations; a form row on a narrow screen.

## What is not covered

There is **no integration test** that drives a real session against a real
server. End-to-end verification was done by hand on a real device; see the
verification note at the top of [../../TASKS.md](../../TASKS.md).
