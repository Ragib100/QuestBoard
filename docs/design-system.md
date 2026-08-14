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

## Type

`google_fonts`: **Outfit** for anything bold — headings, button labels, nav, numbers.
**Inter** for body text and everything else. Never mix a third family.

## Shared widgets

`LabeledField` (`core/widgets/labeled_field.dart`) is the standard form row —
bold label, optional grey helper, then the input. Use it for every form field
rather than rebuilding a label + `TextField` pair per screen.

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

Every screen that loads data needs all four: **loading** (centred
`CircularProgressIndicator`), **error** (message + retry, never a raw exception —
surface `detail` from the API), **empty** (icon + one line + the action that fixes it),
**content**. Destructive actions confirm in a dialog with the danger color.

## Assets

`assets/images/app-icon.png`, `assets/icons/{google,github}.png`. Remote illustrations
from `illustrations.popsy.co` are used on the intro and auth screens — they need
network access at launch, so give every `Image.network` an `errorBuilder`.
