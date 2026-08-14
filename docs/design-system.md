# Design system

Light, clean, modern — closer to Linear or Notion than to a gaming app. Defined once in
`_buildTheme()` in `client/lib/main.dart`. Prefer `Theme.of(context)` over restating
values; the constants below exist because much of the existing UI hardcodes them.

> An earlier spec called for a dark navy + neon palette. It was abandoned once the app
> was built light — see [decisions.md](decisions.md) D2. Do not reintroduce it.

## Color

| Role | Hex | Used for |
|---|---|---|
| Primary | `#0066FF` | Buttons, links, active nav, focus rings |
| Background | `#F8FAFC` | Every `Scaffold` |
| Surface | `#FFFFFF` | Cards, app bars, inputs, sidebar |
| Border | `#E2E8F0` | Card and input outlines, dividers |
| Text primary | `#1E293B` | Headings, body |
| Text secondary | `#64748B` | Captions, metadata, placeholders |
| Subtle fill | `#F1F5F9` | Search field, chips, hover |
| Danger | `#EF4444` | Destructive actions, admin bans, errors |

Points and bounties are the one place to break the blue: use amber `#F59E0B` with a 🪙
so a balance always reads as currency.

## Type

`google_fonts`: **Outfit** for anything bold — headings, button labels, nav, numbers.
**Inter** for body text and everything else. Never mix a third family.

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
