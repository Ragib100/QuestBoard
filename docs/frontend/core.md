# Core

`client/lib/core/` — the helpers every screen leans on. The shared widgets that
live in `core/widgets/` have their own page: [widgets.md](widgets.md). Colors,
type and motion tokens are in [design-system.md](design-system.md).

| File | Lines | Purpose |
|---|---|---|
| `app_colors.dart` | 87 | The palette. The only place a `Color(0xFF…)` literal may appear |
| `breakpoints.dart` | 22 | The one width that separates phone from desktop |
| `app_time.dart` | 90 | Parsing server timestamps and rendering them in Dhaka time |
| `display_name.dart` | 40 | Never render an email address as a name |
| `open_link.dart` | 28 | Opening an external URL, with a clipboard fallback |
| `motion.dart` | 210 | Durations, curves, and four animation helpers |
| `codeforces_web.dart` | 612 | Codeforces hosted inside the app |
| `code_syntax.dart` | 635 | The syntax highlighter |
| `code_format.dart` | 547 | The language-aware re-indenter |

---

## `breakpoints.dart`

```dart
const double wideLayoutWidth = 900;
bool isWideLayout(BuildContext context) =>
    MediaQuery.of(context).size.width > wideLayoutWidth;
```

**Always ask this rather than reading `MediaQuery` directly.** Two screens that
disagree about the answer will contradict each other on screen — which is exactly
what happened: `dashboard.dart` used `> 960` while every other screen used
`> 900`, so in a window between the two the shell drew the **phone** layout
(bottom nav, no sidebar, `embedded: true`) while the tab inside it independently
decided it was on a desktop and drew its wide layout. A desktop grid inside a
phone shell is not a subtle difference, and a window that size is the default on
a Linux desktop ([../decisions.md](../decisions.md) D33).

`test/breakpoints_test.dart` asserts the constant is 900 **and** greps the
source for any screen that hardcodes its own width breakpoint.

## `app_time.dart`

Every date the app shows is Bangladesh time. Two separate bugs live here, and
both were real:

1. **The server sends naive timestamps.** `created_at` arrives as
   `2026-08-20T14:18:09.297403` with no zone, and `DateTime.parse` reads an
   unzoned string as *local* — so a quest posted a moment ago rendered as "6h
   ago" on a phone in Dhaka. Those columns are `timestamp without time zone`
   holding UTC, so `parseServerTime` says so explicitly.
2. **The device's clock is not the product's clock.** A user travelling, or with
   the wrong zone set, would see a different "today" than the one the server pays
   challenges for. `toDhaka` pins rendering to UTC+6 regardless.

| Function | Returns |
|---|---|
| `parseServerTime(raw)` | An unzoned string is read as UTC; an explicit offset is honoured |
| `parseServerDate(raw)` | A plain `YYYY-MM-DD` — a calendar day has no zone to convert, and shifting one moves it a day |
| `toDhaka(instant)` | The same instant with its fields readable as Bangladesh wall-clock time |
| `dhakaNow()` / `dhakaToday()` | Now, and today, in Bangladesh |
| `formatDhakaDate(instant)` | `20 Aug 2026` |
| `timeAgo(instant)` | Compares instants, so the phone's timezone does not matter |

`const Duration dhakaOffset = Duration(hours: 6)` mirrors
`server/app/core/clock.py`. Dart's `DateTime` only knows local and UTC, so
"Dhaka time" here is a UTC instant shifted by the offset and then read with the
`.hour`/`.day` getters — **never do arithmetic on the result**; convert, then
format.

## `display_name.dart`

Signing up seeds `username` with the address the account was created with, so an
account that never finished onboarding is called `someone@gmail.com` everywhere.
That is wrong twice over: it puts an email address in a 28px page heading —
visible to anyone looking at the screen, and to everyone else on a quest tile —
and an address has no spaces, so it cannot wrap. As a heading it broke mid-token
across two lines and ate the top of the home screen
([../decisions.md](../decisions.md) D36).

| Function | Returns |
|---|---|
| `personName({firstName, lastName, username})` | The full name, else the handle |
| `handleOf(username)` | `someone@gmail.com` → `someone`. No `@` means it is already a handle |
| `greetingName({firstName, username})` | The first name alone — "Welcome back, Saif!" — and never an address |

The address is never *shown*; only the part before the `@` is, which is what
people pick as a handle anyway. The model getters (`Profile.displayName`,
`UserSummary.displayName`, `AdminUser.displayName`) all go through here, and
`test/widget_test.dart` asserts they do.

## `open_link.dart`

```dart
Future<String?> openLink(String url)   // null on success, else a message
```

The daily challenge is a link out by design — the points come from a verdict on
Codeforces, so the problem statement lives there. Until this existed the app
displayed the problem URL as text you had to select and paste into a browser
yourself, which is most of the reason claiming "never worked": the flow asks you
to solve it on Codeforces and then made getting there a chore
([../decisions.md](../decisions.md) D37).

Never throws. A device with no browser is unusual but not an error worth
crashing on, and having the link on the clipboard is still a way forward — so
the fallback copies the URL and returns a message saying so.

**Android needs the `https` `<queries>` intent in the manifest** or
`url_launcher` silently fails.

Codeforces links do **not** go through this — they go through `openCodeforces`
below, which falls back to `openLink` where a WebView is not available.

## `codeforces_web.dart`

Codeforces, hosted inside QuestBoard ([../decisions.md](../decisions.md) D43).

The Codeforces API is read-only: no method for submitting a solution, and no
problem statements either — only metadata and verdicts. So "read the problem and
submit it without leaving the app" cannot be built on the API at all. The two
remaining options are to ask people for their Codeforces password and drive the
site as them, or to host Codeforces' own pages. This is the second.

**It never sees a Codeforces credential.** The user signs in on Codeforces' real
login page, the session cookie lives in the platform WebView's own store, nothing
is typed into a form of our making, and the submit button they press is
Codeforces'.

| Symbol | Purpose |
|---|---|
| `canEmbedCodeforces` | True on Android, iOS and macOS. Uses `defaultTargetPlatform`, not `dart:io` — importing `dart:io` at all fails to compile for the web, and `flutter run -d chrome` is one of the ways this project is run |
| `openCodeforces(context, url, {title, prefillCode})` | Hosts the page in-app where possible, hands it to a browser where not |
| `CodeforcesOpen` | `embedded` \| `browser` \| `failed` |
| `CodeforcesSubmit` | `submitted` \| `needsUser` \| … |
| `codeforcesCompilers` | Codeforces' compiler labels per language, in preference order |
| `CodeforcesWebView` | The hosted page itself |

`CodeforcesOpen` matters to the caller: returning from `embedded` means the user
has finished with the page and it is worth re-checking the verdict, while
`browser` returns the instant the browser launches and the user is still over
there.

`prefillCode` is pasted into Codeforces' source box once the page settles. It is
a **convenience, not a bypass** — the code is the user's own, the session is
theirs, and they still choose the language and press Submit themselves.

`codeforcesCompilers` matches against the **text** of the options in Codeforces'
own `programTypeId` select, not their numeric ids: the ids change when they roll
a compiler, and a stale id would submit C++17 code as Python. First regex that
matches any option wins, which is why 64-bit GNU builds come first. A language
with no entry — Dart, TypeScript, Swift, SQL — is one Codeforces does not
accept, and the submitter leaves the form for the user rather than guessing,
because guessing here means a wrong-language verdict.

## `code_syntax.dart`

Syntax highlighting for every code surface in the app.

Hand-rolled rather than pulled from a package: `highlight` and friends ship a
hundred grammars and a set of IDE themes we would have to override anyway, and
the seventeen languages the picker offers all fall into three lexical families —
C-like, hash-comment scripting, and SQL. The whole lexer is smaller than the
theme file alone would be, and it produces the same tokens the re-indenter needs
to know which braces are real and which are inside a string.

| Symbol | Purpose |
|---|---|
| `CodeTokenKind` | `keyword`, `type`, `string`, `number`, `comment`, `meta` |
| `CodeToken` | `start`, `end`, `kind` |
| `_Grammar` / `_grammars` | One entry per language family |
| `CodeHighlightController` | A `TextEditingController` that colours as you type |
| `MaskedCode` | Strings and comments masked out, for the re-indenter to read |

The scanner is **deliberately forgiving**: half the code pasted into the app is a
fragment that does not compile yet, so an unterminated string ends at the newline
and an unterminated block comment ends at the end of the buffer. Neither one is
allowed to paint the rest of the file green.

Colors come from `AppColors.codeKeyword` and friends — never colour code by hand
([design-system.md](design-system.md#code)).

## `code_format.dart`

Re-indents pasted code the way each language's own tooling would
([../decisions.md](../decisions.md) D49).

The editor's old "Indent" button inserted two spaces at the caret, which is not
indenting — it is typing a space twice. This is the real thing: it throws away
every line's leading whitespace and rebuilds it from the structure of the code,
using the indent unit that language's community actually uses — `gofmt` tabs,
PSR-12's four spaces for PHP, two for Dart and JavaScript, PEP 8's four for
Python.

What it deliberately does **not** do is reflow anything. A real formatter —
clang-format, Black, gofmt — parses the language and rewrites line breaks,
spacing and wrapping. There is no parser and no compiler on a phone, and a
half-parser that moves someone's code around would eventually mangle a solution
they are about to submit. Leading whitespace is the part that can be rebuilt from
brackets alone, it is the part that is actually broken in pasted code, and
getting it wrong is visible and harmless.

| Symbol | Purpose |
|---|---|
| `CodeFormatResult` | `code`, `changed`, `styleNote` |
| `formatCode(...)` | The re-indenter |
| `indentAfterNewline(...)` | What `_AutoIndent` uses to carry indentation onto a new line |

`changed` is false when the code was already indented that way, so the caller
says "already formatted" instead of claiming it did something. `styleNote` is
the confirmation text — "4-space indent", "tabs, like gofmt".

Three indentation families are handled: **bracket** languages (C-like),
**Python** (colon + block, with triple-quoted bodies left byte-for-byte alone),
and **keyword** languages — Ruby (`end`/`else`/`when`…) and Bash
(`fi`/`done`/`esac`). Strings and comments come from the lexer, so a brace inside
a string never opens a block.

`test/code_format_test.dart` covers all three families in detail.

## `app_colors.dart` and `motion.dart`

Both are token files, documented in full in
[design-system.md](design-system.md). The rule for each is the same and it is
the reason they exist ([../decisions.md](../decisions.md) D13, D25): the
alternative is every screen picking its own `#2563EB` and its own 250ms
easeInOut until the app looks hand-assembled.

`AppMotion` durations: `fast 120` · `base 200` · `slow 320` · `count 700` ·
`celebrate 900`. Curves: `standard` (easeOutCubic) for entry, `pop`
(easeOutBack) for scale only.

Helpers in `motion.dart`: `appRoute()` for pushes, `FadeSlideIn(index:)` for
staggered list entry (wrap at the call site, not inside the tile),
`TabTransition` for the dashboard's tabs, `CountUpText` for numbers that roll up
when data lands.

**The rule every animation in this app follows:** *animate opacity and transform,
never a value the layout measures, and nothing repeats forever.*
`test/mobile_layout_test.dart` pumps a single frame at 320px and asserts no
overflow — `Opacity` and `Transform` do not change the parent's constraints at
any frame, so the geometry that test measures is identical from frame 0 to
completion. And a pending `Timer` fails a `testWidgets` body outright while an
uncapped `controller.repeat()` hangs `pumpAndSettle()`.
