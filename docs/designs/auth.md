# QuestBoard — UI Design Prompts (Google Stitch)

**Project:** QuestBoard — A Gamified Q&A Platform for STEM Problem Solving  
**Design Tool:** Google Stitch  
**Platform:** Mobile (Flutter — Android first)  
**Design Language:** Gamified, dark-themed, energetic. Think competitive gaming meets academic focus. Bold typography, neon accent colors, achievement-style UI elements.

> Copy each prompt block and paste it directly into Google Stitch. Each prompt is self-contained and describes one screen completely.

---

## Design System Reference

Use these consistently across all screens so Stitch generates cohesive UI.

- **Background:** Deep dark navy `#0D1117`
- **Surface cards:** Dark slate `#161B22`
- **Primary accent:** Electric purple `#7C3AED`
- **Secondary accent:** Neon cyan `#22D3EE`
- **Success / points:** Gold `#F59E0B`
- **Error:** Coral red `#EF4444`
- **Text primary:** White `#FFFFFF`
- **Text secondary:** Muted gray `#8B949E`
- **Font:** Bold geometric sans-serif (like Inter or Space Grotesk)

---

## Auth Pages

---

### Page 1 — Login

```
Design a mobile login screen for QuestBoard, a dark-themed gamified STEM Q&A app where students earn points and badges for helping each other solve problems.

VISUAL STYLE:
- Dark background: deep navy #0D1117
- The screen has a dramatic top section with a glowing purple and cyan gradient radial glow behind the logo, like a spotlight effect on a dark stage
- Gamified, energetic feel — not a plain corporate login screen
- Bold geometric sans-serif typography throughout

TOP SECTION (30% of screen):
- QuestBoard logo centered: a shield icon with a lightning bolt or sword inside it, rendered in electric purple #7C3AED with a subtle neon glow
- Below the logo: app name "QuestBoard" in bold white 28sp
- Below app name: tagline in muted gray "Level up your problem-solving" in 14sp

FORM SECTION (middle):
- Dark card surface #161B22 with 16dp rounded corners, subtle border #30363D, slight drop shadow
- Card contains:
  - Section label "Welcome Back" in bold white 20sp at the top of the card
  - Subtitle "Sign in to continue your quest" in muted gray #8B949E 13sp
  - Email input field: dark filled input #0D1117, label "Email" floating above, left icon is an envelope icon in purple #7C3AED, 12dp rounded corners, 1dp border #30363D
  - Password input field: same style, label "Password", left icon is a lock icon in purple, right side has an eye icon toggle for show/hide password
  - "Forgot Password?" text link right-aligned below the password field, in cyan #22D3EE, 13sp
  - Primary CTA button: full width, bold gradient from purple #7C3AED to cyan #22D3EE, label "SIGN IN" in white bold 16sp, 12dp rounded corners, subtle glow effect under the button matching the gradient colors
  - Divider line with "or" text in muted gray

BOTTOM SECTION:
- "Don't have an account?" in muted gray + "Join the Quest" as a tappable link in electric purple #7C3AED, bold, 14sp
- Both centered on one line

EXTRA DETAILS:
- Subtle particle or dot grid pattern in the background (very low opacity, dark) to give depth without distraction
- The overall feel should resemble a game login screen — prestigious, focused, slightly dramatic
- Status bar icons in white (light status bar)
- No bottom navigation bar on this screen
```

---

### Page 2 — Sign Up: Step 1 (Credentials)

```
Design a mobile sign-up screen Step 1 of 2 for QuestBoard, a dark-themed gamified STEM Q&A app.

VISUAL STYLE:
- Same dark design language as the login screen: background #0D1117, card surface #161B22, primary accent purple #7C3AED, secondary accent cyan #22D3EE
- Gamified, energetic — this is the beginning of the user's "quest"

TOP SECTION:
- Back arrow icon top-left in white
- Centered progress indicator showing Step 1 of 2: two horizontal pill/capsule shapes side by side. The first pill is filled with the purple-to-cyan gradient and labeled "1 Credentials". The second pill is outlined only (unfilled) in muted gray and labeled "2 Profile". This clearly communicates a two-step onboarding journey.
- Below the progress indicator: heading "Create Your Account" in bold white 22sp
- Subtitle: "Start your journey to the leaderboard" in muted gray 13sp — this reinforces the gamified context

FORM SECTION:
- Dark card #161B22, 16dp rounded corners, border #30363D
- Card contains:
  - Email input field: dark filled #0D1117, floating label "Email", left icon envelope in purple #7C3AED, 12dp rounded corners, 1dp border
  - Password input field: floating label "Password", left lock icon in purple, right eye toggle icon. Below the field: a password strength bar — a thin horizontal bar that fills from left to right in color: red for weak, amber for medium, green for strong. Label "Password strength" in 11sp muted gray beside it.
  - Confirm Password input field: floating label "Confirm Password", left lock icon, right eye toggle. If passwords match, show a small green checkmark on the right. If they don't match, show a red X and a red helper text below: "Passwords do not match"

BOTTOM SECTION:
- Full width CTA button: gradient purple to cyan, label "CONTINUE" in white bold 16sp, 12dp rounded corners, glow effect
- Below the button: "Already have an account?" in muted gray + "Sign In" in purple, centered

EXTRA DETAILS:
- Small shield icon with a star badge watermark (very low opacity 5%) in the background for depth
- A subtle golden star or XP icon near the subtitle to hint that signing up earns the user their first 100 points
- Same dot-grid subtle background pattern as the login screen
```

---

### Page 3 — Sign Up: Step 2 (Profile Details)

```
Design a mobile sign-up screen Step 2 of 2 for QuestBoard, a dark-themed gamified STEM Q&A app. This screen collects the user's profile information after their email has been verified.

VISUAL STYLE:
- Same dark design system: background #0D1117, surface #161B22, accent purple #7C3AED, cyan #22D3EE, gold #F59E0B
- The tone here should feel like "setting up your game character" — this is the player profile creation moment

TOP SECTION:
- Back arrow top-left in white
- Progress indicator: two pills. First pill "1 Credentials" is now in muted gray (completed). Second pill "2 Profile" is filled with the purple-to-cyan gradient (active). A small golden checkmark icon appears inside or beside the first pill to show it is done.
- Avatar placeholder: centered circle (80dp diameter) with a camera icon inside, border is a dashed purple circle, label "Add Photo" in purple 12sp below it — the user can tap to upload a profile picture
- Heading "Set Up Your Profile" bold white 22sp
- Subtitle "Tell us who you are, adventurer" in muted gray 13sp — keeps the gamified tone

FORM SECTION (scrollable):
- Dark card #161B22, 16dp rounded corners
- Fields inside the card (all with floating labels, purple icons, dark fill):
  - Username field — left icon: person outline — placeholder hint text "Choose a unique username" — below it a small note in muted gray 11sp: "This is your public display name on the leaderboard"
  - First Name field — left icon: person outline
  - Last Name field — left icon: person outline
  - Phone Number field — left icon: phone icon — input type numeric with country code prefix (+880 for Bangladesh shown by default)
  - District dropdown — left icon: map pin icon — shows a dropdown arrow on the right — placeholder "Select District"
  - City field — left icon: building icon — text input
  - A horizontal divider line with label "Academic Info" in muted gray 11sp centered — this starts a second sub-group of fields
  - Institution field — left icon: graduation cap icon — placeholder "Your university or school"

BOTTOM SECTION:
- Full width CTA button: gradient purple to cyan, label "START MY QUEST" in bold white 16sp, 12dp rounded corners, glowing effect
- Below button: a small row showing a gold coin icon + text "You will receive 100 🪙 points for completing your profile" in gold #F59E0B 12sp — this is a gamified reward hint
- Safe area padding at the bottom

EXTRA DETAILS:
- The scroll should be smooth — form is long so the card scrolls independently
- Show a subtle level-up style animation hint in the design (like a small XP bar at the very top below the progress indicator) showing 0% filled — this will animate to 100% when they complete the form, but show the empty state in the design
- Keep all input borders #30363D unfocused, purple #7C3AED when focused
```

---

### Page 4 — Forgot Password: Step 1 (Email Entry)

```
Design a mobile Forgot Password screen Step 1 of 2 for QuestBoard, a dark-themed gamified STEM Q&A app.

VISUAL STYLE:
- Same dark design system: background #0D1117, surface #161B22, accent purple #7C3AED, cyan #22D3EE
- The tone should feel reassuring and calm — the user is locked out and needs help, not more anxiety

TOP SECTION:
- Back arrow top-left in white
- Large centered illustration or icon: an envelope with a broken lock or a key icon in front of it, rendered in purple and cyan gradient with a soft glow. Size approximately 90dp. This is the hero visual for the screen.
- Heading "Forgot Password?" in bold white 22sp, centered
- Subtitle in muted gray 14sp centered, two lines: "No worries. Enter your registered email and we'll send you a reset link."

FORM SECTION:
- Dark card #161B22, 16dp rounded corners, border #30363D
- Single input field only:
  - Email input: dark fill #0D1117, floating label "Email Address", left icon envelope in purple #7C3AED, 12dp rounded corners, 1dp border
  - Below the input: a helper note in muted gray 12sp: "Make sure to check your spam folder too"

BOTTOM SECTION:
- Full width CTA button: gradient purple to cyan, label "SEND RESET LINK" in bold white 16sp, 12dp rounded corners, glowing effect
- Below button: "Remember your password?" in muted gray + "Sign In" in purple #7C3AED, centered 13sp

EXTRA DETAILS:
- Progress indicator at the top showing Step 1 of 2: two pill shapes. First pill filled (purple-cyan gradient) labeled "1 Email". Second pill outlined muted gray labeled "2 Reset".
- The overall screen should feel spacious — lots of breathing room around the card since there is only one field
- Subtle dot-grid background pattern at very low opacity
```

---

### Page 5 — Forgot Password: Step 2 (New Password Entry)

```
Design a mobile Forgot Password screen Step 2 of 2 for QuestBoard, a dark-themed gamified STEM Q&A app. The user has confirmed their email and now needs to set a new password.

VISUAL STYLE:
- Same dark design system: background #0D1117, surface #161B22, accent purple #7C3AED, cyan #22D3EE, success green #22C55E
- Tone: empowering — the user is regaining access, like unlocking a door

TOP SECTION:
- Back arrow top-left in white
- Progress indicator: two pills. First pill "1 Email" now shown in muted gray with a small golden checkmark (completed). Second pill "2 Reset" filled with purple-to-cyan gradient (active).
- Large centered illustration: an open padlock icon with a key inserted, glowing in green #22C55E with a soft radial glow — signals success and access being restored. Size approximately 90dp.
- Heading "Set New Password" in bold white 22sp, centered
- Subtitle in muted gray 13sp centered: "Create a strong password to protect your account"

FORM SECTION:
- Dark card #161B22, 16dp rounded corners, border #30363D
- Fields:
  - New Password input: dark fill #0D1117, floating label "New Password", left lock icon in purple, right eye toggle. Below: password strength indicator bar — thin horizontal bar, fills left to right, red for weak / amber for medium / green for strong, with small label "Password strength" in 11sp muted gray.
  - Confirm New Password input: floating label "Confirm New Password", left lock icon in purple, right eye toggle. If passwords match: green checkmark on the right + green border. If mismatch: red X + red helper text "Passwords do not match" below.
- Password requirements checklist below the fields inside the card:
  - Four small rows, each with a circle checkbox icon on the left:
    - "At least 8 characters" — unchecked gray by default, turns green with checkmark when met
    - "One uppercase letter"
    - "One number"
    - "One special character"
  - This is a live checklist — design shows the default all-unchecked state

BOTTOM SECTION:
- Full width CTA button: gradient purple to cyan, label "RESET PASSWORD" in bold white 16sp, 12dp rounded corners, glowing effect. Button is slightly desaturated / lower opacity to suggest it is disabled until both passwords match and requirements are met — show the disabled state in the design.
- Below button: small text in muted gray 12sp centered: "You will be redirected to login after reset"

EXTRA DETAILS:
- Subtle dot-grid background at very low opacity
- The locked/unlocked padlock illustration should feel like a game "unlock" moment — use a glow effect that feels rewarding
- Keep the screen focused — no distractions, just the two fields and the checklist
```

---

## Notes for Next Pages

The following pages will be added to this file in upcoming sessions:

- **Home Feed** — question cards with bounty badges, tag chips, vote counts
- **Question Detail** — full question, code/LaTeX rendering, answers, accept button, AI hint button
- **Post Question** — form with tag selector, bounty slider, image scanner button
- **Daily Challenge** — problem display, timer, solve button, leaderboard tab
- **Leaderboard** — weekly/all-time tabs, ranked user cards with avatars and points
- **User Profile** — stats, badge grid, streak display, question history
- **Notifications** — notification list with type icons and timestamps
- **Settings** — dark mode toggle, change password, notification preferences