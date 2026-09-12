# Shared widgets

Everything in `client/lib/core/widgets/`. Each of these exists because the same
shape had been hand-written across several screens and had already drifted —
reach for one before writing a `Container(decoration: BoxDecoration(...))` or a
bare `showSnackBar`.

| File | Exports |
|---|---|
| `app_card.dart` | `AppCard` |
| `app_snack.dart` | `SnackTone`, `showAppSnack` |
| `async_states.dart` | `LoadingState`, `ErrorState`, `ReconnectingState`, `EmptyState`, `PointsBadge`, `VoteControl` |
| `brand_art.dart` | `BrandArt` |
| `code_composer.dart` | `CodeComposer` |
| `code_view.dart` | `codeLanguages`, `maxCodeChars`, `codeTextStyle`, `CodeBlock`, `AttachmentChip` |
| `labeled_field.dart` | `LabeledField` |
| `reward_burst.dart` | `showRewardBurst` |
| `search_field.dart` | `SearchField` |
| `skeletons.dart` | `SkeletonPulse`, `SkeletonBox`, `SkeletonCircle`, and seven shape-specific skeletons |

---

## `AppCard`

The standard card: white, 1px border, radius 16, **no shadow**.

This shape was hand-written about fifteen times across the app and the radius had
drifted to 16, 20 and 24 depending on the screen; two call sites had also picked
up a `boxShadow`, which the design system forbids outright.

`color` defaults to `AppColors.surface` — pass a tint for callout cards.
`borderColor` defaults to `AppColors.border` — pass `AppColors.danger` for
destructive states, matching the suspended-user tile in admin.

## `showAppSnack(context, message, tone:)`

Transient feedback, colour-coded. `SnackTone` is `neutral`, `success`, `error`.

Every one of these used to be a bare
`ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)))`, so
"Quest posted" and "Your session has expired" arrived looking identical. Base
styling (floating, radius 12, Inter 14) comes from `snackBarTheme` in
`main.dart`; this only adds the tone.

**Never call `showSnackBar` directly.**

## The four states — `async_states.dart`

Every screen that loads data needs all four: loading, error, empty, content.

### `LoadingState`
A centred spinner for a screen still loading its first data. Prefer a
**skeleton** wherever the layout is predictable; keep this only where the
content is a single block whose shape is not worth mirroring.

### `ErrorState`
Always shows the API's own message plus a way to recover — **never a raw
exception**.

Set `offline:` when the request never reached a server. That failure is the one
that fixes itself, so it is drawn as `ReconnectingState` instead of an error with
a button. A `403` will still be a `403` in ten seconds; a train going into a
tunnel will not ([../decisions.md](../decisions.md) D46).

### `ReconnectingState`
Waiting for the connection to come back, and retrying by itself.

Replaces the dead end this used to be: an unreachable server produced an error
page with a **Try again** button, so a phone that lost signal for four seconds
needed a tap to recover, and a user watching a sleeping free-tier dyno wake up
had no idea whether tapping would help.

### `EmptyState`
Icon + one line + the action that fixes it. Never an invented number and never a
fake row (ground rule 4).

### `PointsBadge` and `VoteControl`
The amber coin pill and the up/down score control. Both are layout-tested at
320px with four-digit values, because a big balance blowing out a row is the
failure mode.

## `LabeledField`

The standard form row: a bold label, an optional grey helper, then the input.
Replaces the per-screen `_buildLabel` / `_buildField` helpers that used to be
copy-pasted into every form. **Use it for every form field.**

- `obscureText` starts the field hidden and adds a reveal toggle, so users can
  check what they typed before submitting. Non-password fields get no toggle.
- `autofillHints` lets the platform's password manager recognise the field —
  wrap the surrounding form in an `AutofillGroup` or Android will never offer to
  save the credentials.
- `maxLength` is a hard ceiling enforced **silently**. Deliberately not
  `TextField.maxLength`, which draws a "0/50000" counter: the limit exists to
  bound the row, not to set a target.

## `SearchField`

A search box that fires once the user stops typing — it owns the controller, the
350ms debounce timer and the clear button.

Three screens had grown their own copy of all three and they had already drifted:
one trimmed the term before comparing it and the others did not, so a trailing
space re-ran the same query.

`onChanged` is called with the **trimmed** term, at most once per pause, and
immediately when the field is cleared. `initialValue` accepts a term pushed in
from outside — the dashboard's search box hands one to the Browse tab — and
changing it updates the field without re-notifying. `bordered: false` drops the
border for a field that already sits inside its own container, like the desktop
shell's rounded pill.

## Code surfaces

### `codeLanguages`, `maxCodeChars`, `codeTextStyle`

`codeLanguages` (17 entries) **must match `LANGUAGES` in
`server/app/schemas/code.py`** — the server rejects anything else, and the column
is a `varchar(20)`. `maxCodeChars = 20000` is the same ceiling as
`MAX_CODE_CHARS`, enforced client-side too so the limit is a counter that ticks
down rather than a `422` after a long paste.

`codeTextStyle` is deliberately a **platform monospace font**, not a
`google_fonts` face: code is the one thing that must still render as code with no
network, and every device already ships a monospace family. Its `height` is fixed
so the read-only block's line-number gutter lines up with the lines it numbers.

### `CodeBlock`
Read-only submitted code: language header, line-number gutter, copy button,
syntax colours from `code_syntax.dart`. Long lines scroll sideways rather than
wrapping, because wrapped code is misleading code.

### `AttachmentChip`
The labelled link to an uploaded file, using `attachment_name` so the UI has
something to show other than a URL.

### `CodeComposer`
The in-app editor: write or paste code, label its language, optionally attach a
file. Offers `Fix indent` and `Indent` (from `code_format.dart`), colours as you
type, carries indentation onto a new line via `_AutoIndent`, and makes
**Tab / Shift-Tab indent instead of moving focus**
([../decisions.md](../decisions.md) D49).

Collapsed to a single button until it is needed — most answers are prose, and an
always-open code pane would push the actual composer off a phone screen. It
reports every change through `onChanged` and the parent decides what to do, which
is what lets one widget serve both the answer composer and the challenge claim
sheet.

`collapsedLabel` differs by caller — the challenge sheet says "Attach your
solution", the answer composer just "Add code". `onSubmit` draws a primary
button under the editor; the answer composer leaves it null because it has its
own send button and a second one would be ambiguous.

## `BrandArt`

The decorative mark on the landing page and the two auth screens.

Replaces three `Image.network` calls pointing at `.svg` files on
`illustrations.popsy.co`. Flutter's image codecs cannot decode SVG without
`flutter_svg`, so those `errorBuilder`s fired **every single time on every
platform** — the "illustration" had only ever been a fallback icon.

Drawn locally with a `CustomPainter` rather than adding `flutter_svg` and keeping
the remote URLs, because the first screen of a live demo should not depend on a
network fetch. Purely geometric: no numbers, no invented usernames, nothing that
could read as fabricated content ([../decisions.md](../decisions.md) D12).

**Do not reintroduce a remote image on a launch path.**

## `showRewardBurst(context, ...)`

A one-shot celebration for the two moments the app actually rewards you:
accepting an answer (the bounty transfers) and claiming the daily challenge.

Drawn with a `CustomPainter` rather than a confetti package — D25 keeps this app
on SDK primitives only.

It lives in the `Overlay`, which has two useful consequences: it cannot affect
any screen's layout, so it is **structurally incapable** of overflowing at 320px;
and it survives the `setState` that follows the API call that triggered it.

## Skeletons

`SkeletonPulse` wraps a subtree; `SkeletonBox` and `SkeletonCircle` are the
primitives; the shape-specific ones are `ListSkeleton`, `QuestTileSkeleton`,
`LeaderboardRowSkeleton`, `LedgerRowSkeleton`, `StatGridSkeleton`,
`QuestDetailSkeleton`, `NotificationRowSkeleton` and `ProfileSkeleton`.

A spinner says "wait"; a skeleton says "a list of quests is arriving", and it is
the difference between the app looking half-built and looking finished during the
seconds a demo actually spends on it.

### Why the pulse stops

The usual way to write this is `controller.repeat(reverse: true)`, which never
completes and therefore makes any future `tester.pumpAndSettle()` time out.
Instead the pulse runs a capped number of cycles and then rests. Nothing loads
for seven seconds and still succeeds — past that it is a broken connection, not
a load, and the error state is what should be on screen anyway.

`test/mobile_layout_test.dart` asserts that skeletons settle instead of pulsing
forever.
