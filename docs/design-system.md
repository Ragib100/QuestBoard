# Design system

Light, clean, modern — closer to Linear or Notion than to a gaming app. The widget
theme lives in `_buildTheme()` in `client/lib/main.dart`; the palette lives in
`AppColors` (`client/lib/core/app_colors.dart`).

**Never write a raw `Color(0xFF...)` literal in a screen** — use `AppColors`, or
`Theme.of(context)` where the theme already carries the value.

> An earlier spec called for a dark navy + neon palette. It was abandoned once the app
> was built light — see [decisions.md](decisions.md) D2. Do not reintroduce it.

## Color

| Token | Hex | Used for |
|---|---|---|
| `AppColors.primary` | `#0066FF` | Buttons, links, active nav, focus rings |
| `AppColors.primaryDark` | `#0052CC` | Pressed / darker primary |
| `AppColors.background` | `#F8FAFC` | Every `Scaffold` |
| `AppColors.surface` | `#FFFFFF` | Cards, app bars, inputs, sidebar |
| `AppColors.border` | `#E2E8F0` | Card and input outlines, dividers |
| `AppColors.textPrimary` | `#1E293B` | Headings, body |
| `AppColors.textSecondary` | `#64748B` | Captions, metadata |
| `AppColors.textMuted` | `#94A3B8` | Placeholders, timestamps |
| `AppColors.subtleFill` | `#F1F5F9` | Search field, chips, hover |
| `AppColors.primaryTint` | `#E0F2FE` | Tinted chips and icon circles |
| `AppColors.success` | `#22C55E` | Accepted answers, solved quests |
| `AppColors.danger` | `#EF4444` | Destructive actions, admin bans, errors |

Points and bounties are the one place to break the blue: use amber `#F59E0B` with a 🪙
so a balance always reads as currency.

### Code

Code is the one surface with a palette of its own, applied by the lexer in
`core/code_syntax.dart` — never colour code by hand. All six sit on
`subtleFill`, the fill behind every code block and the editor.

| Token | Hex | Used for |
|---|---|---|
| `AppColors.codeKeyword` | `#7C3AED` | `if`, `class`, `return` — the language's own words (semibold) |
| `AppColors.codeType` | `#0F766E` | Built-in types and library names: `int`, `String`, `vector` |
| `AppColors.codeString` | `#15803D` | String and character literals |
| `AppColors.codeNumber` | `#B45309` | Numeric literals |
| `AppColors.codeComment` | `#7C8798` | Comments (italic) |
| `AppColors.codeMeta` | `#BE185D` | `#include`, `@Override`, `<?php` |

`text` has no grammar, so sample input and output render plain — that is the
point of the `text` option, not a gap.

## Type

`google_fonts`: **Outfit** for anything bold — headings, button labels, nav, numbers.
**Inter** for body text and everything else. Never mix a third family.

The theme in `_buildTheme()` carries a full type scale — 56/38/28/24/20/18 in Outfit
for headings and chrome, 16/14/13/12 in Inter for body and metadata. Prefer
`Theme.of(context).textTheme` over a local `GoogleFonts.*` call. Screens written
before the scale existed still carry local calls, which override the theme; migrate
them opportunistically when you are already in the file.

## Shared widgets

All in `core/widgets/`.

| Widget | Use it for |
|---|---|
| `LabeledField` | The standard form row — bold label, optional grey helper, then the input. Use it for every form field rather than rebuilding a label + `TextField` pair. |
| `AppCard` | The standard card — white, 1px border, radius 16, no shadow. Use instead of a hand-written `BoxDecoration`. |
| `LoadingState` / `ErrorState` / `EmptyState` | The three non-content states (`async_states.dart`). |
| `PointsBadge` / `VoteControl` | The amber coin pill and the up/down score control. |
| `SearchField` | Owns its controller and a 350ms debounce. |
| `showAppSnack(context, msg, tone:)` | All transient feedback. Tones: `success`, `error`, `neutral`. Never call `showSnackBar` directly. |
| `SkeletonPulse` + `*Skeleton` | Loading placeholders — see Motion below. |
| `BrandArt` | The decorative mark on the landing and auth screens. |
| `showRewardBurst(context, ...)` | The one-shot celebration for a bounty transfer or a claimed challenge. |
| `CodeBlock` | Read-only code: language header, line-number gutter, copy button, syntax colours, long lines scroll sideways. |
| `CodeComposer` | The editor: language picker, `Fix indent`, `Indent`, attach a file. Colours as you type, carries indentation onto a new line, and Tab / Shift-Tab indent instead of moving focus (decisions.md D49). |

## Motion

Durations and curves live in `AppColors`' sibling, `core/motion.dart` — never hardcode
a `Duration` in a screen. `fast 120` / `base 200` / `slow 320` / `count 700` /
`celebrate 900`; `standard easeOutCubic` for entry, `pop easeOutBack` for scale only.

**The rule:** *animate opacity and transform, never a value the layout measures, and
nothing repeats forever.*

`test/mobile_layout_test.dart` pumps one frame at 320px and asserts no overflow, so an
animated height would have it measuring a layout that never appears on screen. And a
pending `Timer` fails a `testWidgets` body outright while an uncapped
`controller.repeat()` hangs `pumpAndSettle()` — so every animation is one-shot or
cycle-capped. `SkeletonPulse` stops after six cycles for exactly this reason, and a test
asserts that it does.

There are **no exceptions**. `LeaderboardPodium` looks like one — its pedestals rise —
but they are laid out at full height from frame 0 and only *drawn* growing, via a
`scaleY` transform. The first version did tween the height inside a fixed-height box,
which passed the widget test and overflowed in real use; see [decisions.md](decisions.md)
D25.

**Testing animated widgets:** a single `pump()` measures frame 0, which for an entry
animation is the state nobody ever sees. Always `pumpAndSettle()` before asserting, and
run the text scales — 1.0 through 2.0 — because a layout that fits at default scale is
not the same layout at 1.5x.

Helpers: `appRoute()` for pushes, `FadeSlideIn(index:)` for staggered list entry (wrap at
the call site, not inside the tile), `TabTransition` for the dashboard's tabs,
`CountUpText` for numbers that roll up when data lands.

No animation package — see [decisions.md](decisions.md) D25.

## Shape and spacing

Radius: 12 on buttons and inputs, 16 on cards, 20 on pills and search fields.
Padding: 20 on screens, 16–20 inside cards. Gaps in multiples of 4 (8/12/16/24/32).
Cards are `elevation: 0` with a `#E2E8F0` border — the app has no shadows. Primary
buttons are full width at `minimumSize: (double.infinity, 54)`.

## Responsive

One widget renders both layouts off a `MediaQuery` width check — never fork into two
screen classes.

| Breakpoint | Behaviour |
|---|---|
| `> 960` (shell) | Sidebar nav + top bar with search |
| `> 900` (content) | Web header instead of `AppBar`, no FAB |
| otherwise | `AppBar` + bottom nav + FAB |

Content sits in a `ConstrainedBox`: `maxWidth: 900` for lists and forms, `1400` for the
dashboard shell.

## States

Every screen that loads data needs all four: **loading**, **error** (message + retry,
never a raw exception — surface `detail` from the API), **empty** (icon + one line + the
action that fixes it), **content**. Destructive actions confirm in a dialog with the
danger color.

For **loading**, prefer a skeleton that mirrors the shape of what is arriving
(`QuestTileSkeleton`, `LeaderboardRowSkeleton`, `ProfileSkeleton`, …) over a bare
spinner. Keep `LoadingState` only where the content is a single block whose shape is not
worth mirroring.

## Assets

`assets/images/app-icon.png` is the only bundled image; `dart run flutter_launcher_icons`
regenerates the Android mipmaps, the web icons and the Windows icon from it. The Android
splash lives in `drawable/` **and** `drawable-v21/launch_background.xml` (edit both) plus
`values-v31/styles.xml` for API 31+, which ignores `windowBackground` entirely.

Decorative art is drawn locally with `CustomPainter` (`BrandArt`). The intro and auth
screens previously used remote `illustrations.popsy.co` SVGs via `Image.network`, which
Flutter cannot decode without `flutter_svg` — they fell through to the `errorBuilder` on
every platform, every time. Do not reintroduce a remote image on a launch path.
