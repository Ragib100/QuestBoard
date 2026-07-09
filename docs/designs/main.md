# QuestBoard — UI Design Prompts (Google Stitch)
## Pages: Home Feed · Question Detail · Post Question · Daily Challenge · Leaderboard

**Project:** QuestBoard — A Gamified Q&A Platform for STEM Problem Solving  
**Design Tool:** Google Stitch  
**Platform:** Mobile (Flutter — Android first)  
**Reference:** Auth screens already designed — maintain exact same design system below.

---

## Design System Reference

> Keep these identical to the auth screens for visual consistency.

- **Background:** Deep dark navy `#0D1117`
- **Surface cards:** Dark slate `#161B22`
- **Primary accent:** Electric purple `#7C3AED`
- **Secondary accent:** Neon cyan `#22D3EE`
- **Success / points:** Gold `#F59E0B`
- **Error:** Coral red `#EF4444`
- **Text primary:** White `#FFFFFF`
- **Text secondary:** Muted gray `#8B949E`
- **Border:** `#30363D`
- **Font:** Bold geometric sans-serif (Inter or Space Grotesk)
- **Bottom nav bar:** Dark surface `#161B22` with top border `#30363D`

---

## Page 1 — Home Feed

```
Design a mobile Home Feed screen for QuestBoard, a dark-themed gamified STEM Q&A app where students earn points and badges for helping each other solve problems. This is the main screen users see after logging in.

VISUAL STYLE:
- Dark background #0D1117, same design language as the auth screens
- Energetic and gamified — this is the "arena" where questions live
- Card-based layout with clear hierarchy
- Subtle dot-grid background pattern at very low opacity throughout

TOP BAR (app bar):
- Background #161B22, bottom border #30363D, elevation shadow
- Left side: QuestBoard shield logo icon in purple #7C3AED (small, 28dp) + app name "QuestBoard" in bold white 18sp beside it
- Right side: two icon buttons side by side:
  - Bell icon for notifications — has a small red circle badge with number "3" on top-right corner indicating unread count
  - Circular avatar (32dp) of the logged-in user — tapping goes to profile
- Below the app bar title row: a search bar stretching full width with horizontal padding 16dp. Dark fill #0D1117, 12dp rounded corners, border #30363D, left search icon in muted gray, placeholder text "Search questions..." in muted gray. This search bar is part of the app bar area, not the scrollable content.

TAG FILTER ROW (below search bar, horizontally scrollable):
- Horizontal scrollable row of filter chips, no scroll indicator
- First chip: "All" — selected state: filled purple-to-cyan gradient, white text, slight glow. Unselected: outlined #30363D, muted gray text
- Remaining chips (unselected): "DSA", "Math", "Physics", "Calculus", "Graph Theory", "Chemistry" — each as outlined pill chips with tag name in muted gray, 8dp rounded corners
- Left edge has a subtle sort icon button (sliders icon) in muted gray that opens sort options

SORT BAR (below filter row):
- Single row with muted gray 12sp text on left: "248 questions" showing the count
- Right side: a small dropdown/toggle showing current sort: "Latest ▾" in cyan #22D3EE 12sp

QUESTION CARDS (scrollable feed):
Each question card is a dark surface #161B22, 12dp rounded corners, border #30363D, 16dp padding, 12dp gap between cards, 16dp horizontal margin.

Card anatomy (design 3 cards to show variety):

CARD 1 — Unsolved question with high bounty:
- Top row: 
  - Left: tag chip "DSA" — small filled chip, purple background at 20% opacity, purple text #7C3AED, 6dp rounded corners
  - Right: bounty badge — gold coin icon + "30 pts" in gold #F59E0B bold — inside a dark gold-bordered pill shape. This is the most visually prominent element on the card to draw attention.
- Question title: "How do I solve a bitmask DP problem efficiently?" — bold white 15sp, max 2 lines, ellipsis overflow
- Question preview body: muted gray 13sp, 2 lines max — "I'm stuck on this Codeforces problem where I need to iterate over all subsets..."
- Bottom row:
  - Left: small circular avatar (20dp) + username "saif_ahmed" in muted gray 12sp + "· 2h ago" in muted gray 12sp
  - Right side icons row: 
    - Upvote icon (chevron up) + count "12" in muted gray 12sp
    - Comment/answer icon + count "3" in muted gray 12sp
    - Eye icon + "142" in muted gray 12sp

CARD 2 — Solved question (no bounty):
- Same structure but:
  - Top right: instead of bounty badge, show a green "✓ Solved" pill badge — dark green background, green #22C55E text and checkmark icon, 6dp rounded corners
  - Tag chip: "Math" in purple tint
  - Title: "Prove that the sum of first n odd numbers is n²"
  - Bottom row same structure
  - The card border has a very subtle green left accent line (3dp wide left border in green #22C55E) to visually distinguish solved questions

CARD 3 — Unsolved question with AI hint indicator:
- Top row: tag chip "Physics" + bounty badge "15 pts" in gold
- A small row below the tags showing a purple sparkle/wand icon + "2 hints used" in purple #7C3AED 11sp — shows AI engagement
- Title: "Why does a capacitor block DC but allow AC current?"
- Bottom row same structure

FLOATING ACTION BUTTON (FAB):
- Bottom right corner, above the bottom nav bar
- Large circular FAB (56dp): purple-to-cyan gradient fill, white "+" icon (24dp), circular glow effect matching the gradient underneath
- Label "Ask" appears as a small white text beside the FAB — extended FAB style

BOTTOM NAVIGATION BAR:
- Background #161B22, top border 1dp #30363D
- Five tabs evenly spaced:
  1. Home — house icon — ACTIVE: icon filled purple #7C3AED + label "Home" in purple 10sp + small purple dot indicator below
  2. Challenges — lightning bolt icon — inactive: muted gray icon + label "Challenges" 10sp
  3. Post (center) — this tab is replaced by the FAB above, so it is empty/no tab in the middle, FAB floats over this space
  4. Leaderboard — trophy icon — inactive muted gray + label "Leaderboard" 10sp
  5. Profile — person icon — inactive muted gray + label "Profile" 10sp

EXTRA DETAILS:
- Pull-to-refresh indicator uses purple color
- Subtle dot-grid background behind everything at 3% opacity
- Each card has a hover/pressed state darkening for tap feedback
- Status bar white icons
- Show exactly 2.5 cards visible initially (third card partially cut off) to signal scrollability
```

---

## Page 2 — Question Detail

```
Design a mobile Question Detail screen for QuestBoard, a dark-themed gamified STEM Q&A app. This screen shows the full question, all answers, and actions the user can take.

VISUAL STYLE:
- Dark background #0D1117, same design system as auth and home feed screens
- This is the most content-heavy screen — prioritize readability and clear visual hierarchy
- Long scrollable screen — the app bar and action bar stay fixed, content scrolls

FIXED TOP APP BAR:
- Background #161B22, bottom border #30363D
- Left: back arrow in white
- Center: "Question" in bold white 16sp
- Right: three-dot menu icon in muted gray (for report/share options)

SCROLLABLE CONTENT AREA:

QUESTION SECTION (top of scroll):
- Dark card #161B22, 12dp rounded corners, 16dp padding, 16dp horizontal margin, border #30363D

  QUESTION HEADER:
  - Tag chips row: "DSA" chip + "Dynamic Programming" chip — small filled purple-tint pills
  - Bounty badge top right: gold coin icon + "30 pts" in gold #F59E0B bold pill — prominent
  - Question title: "How do I solve a bitmask DP problem efficiently?" — bold white 20sp, full wrap
  - Author row: circular avatar 28dp + "saif_ahmed" bold white 13sp + "Level 4 · 340 pts" in muted gray 12sp + "· 2 hours ago" in muted gray — all on one line
  - Thin divider line #30363D

  QUESTION BODY:
  - Body text in white 14sp, line height 1.6, 16dp padding
  - Code block example: dark #0D1117 background, 8dp rounded corners, thin left border 3dp in cyan #22D3EE, monospace font, syntax highlighted — keywords in purple, strings in gold, comments in muted gray. A small "C++" label badge top-right of the code block in muted gray. Copy icon top-right corner of code block.
  - Math/LaTeX block example: centered, white formula rendered cleanly against dark background
  - Image attachment (if any): 12dp rounded corner image, full width

  QUESTION ACTIONS ROW (below body):
  - Row of action buttons with 16dp padding:
    - Upvote button: chevron-up icon + count "12" — when voted: filled purple background pill, purple icon + white count. When not voted: outlined muted gray
    - Downvote button: chevron-down icon — same toggle style
    - Share icon button: muted gray
    - Bookmark icon button: muted gray
  - Right side: view count "142 views" in muted gray 12sp with eye icon

  AI HINT BUTTON (below actions row):
  - Full width button inside the question card
  - Style: dark background #0D1117, dashed border 1dp in purple #7C3AED, 10dp rounded corners
  - Left: sparkle/wand icon in purple
  - Center text: "Get AI Hint" in purple bold 14sp
  - Right: gold coin icon + "5 pts" in gold — shows the cost
  - Below the button in muted gray 11sp: "Guides you without giving the answer · 2 hints used"

ANSWERS SECTION HEADER:
- Outside the question card, 16dp horizontal margin
- "3 Answers" in bold white 16sp on left
- Sort dropdown "Best ▾" in cyan 13sp on right

ANSWER CARDS (one per answer, show 2 answers):

ANSWER CARD 1 — Accepted answer:
- Card background #161B22, border: 1dp solid green #22C55E (entire card border glows green to show it is the accepted answer)
- Top right: "✓ Accepted" badge — green filled pill, white checkmark + "Accepted" text
- Author row: avatar 24dp + "rifat_22" bold white 13sp + "Level 6 · 520 pts" muted gray + "· 1h ago"
- Answer body text white 14sp, line height 1.6
- Code block if present — same style as question body
- Bottom row:
  - Upvote/downvote same style as question actions
  - "7 votes" count
  - Reply icon in muted gray

ANSWER CARD 2 — Regular answer:
- Same card style but with default border #30363D (not green)
- No accepted badge
- Same anatomy as Card 1

POST YOUR ANSWER TEASER (bottom of scroll, above fixed bar):
- A tappable card with dashed border #30363D, 12dp rounded corners, 16dp padding
- Centered content: pencil/edit icon in purple + "Write your answer and earn 30 pts" in muted gray 14sp
- The gold bounty amount is highlighted in gold #F59E0B

FIXED BOTTOM ACTION BAR:
- Background #161B22, top border #30363D, 16dp padding
- If question is solved: show "Question Solved" in green with checkmark — no CTA
- If unsolved: full width CTA button gradient purple to cyan "POST YOUR ANSWER" white bold 15sp with glow
- Left of button (or above): small row showing current bounty "🪙 30 pts up for grabs" in gold 12sp

EXTRA DETAILS:
- The accepted answer's green glow is the most important visual signal on this screen — make it obvious
- Code blocks must feel like a proper IDE — dark, monospace, with the cyan left accent border
- Dot-grid background at very low opacity throughout
- Smooth scroll — question section stays at top as user scrolls to answers
```

---

## Page 3 — Post Question

```
Design a mobile Post Question screen for QuestBoard, a dark-themed gamified STEM Q&A app. This is the form where users write and submit a new question with an optional point bounty.

VISUAL STYLE:
- Dark background #0D1117, same design system throughout
- This screen should feel like a "mission briefing" form — the user is crafting a quest for others to solve
- Clean, focused, minimal distractions — the form is the entire screen

FIXED TOP APP BAR:
- Background #161B22, bottom border #30363D
- Left: "✕" close icon in white (dismisses and goes back)
- Center: "Post a Question" in bold white 16sp
- Right: "Post" text button in purple #7C3AED bold 15sp — disabled (muted gray) until required fields are filled

SCROLLABLE FORM CONTENT (16dp horizontal padding throughout):

REWARD HINT BANNER (top of scroll):
- Full width banner card, dark gold border #F59E0B at 30% opacity, background gold at 5% opacity, 10dp rounded corners, 12dp padding
- Left: gold coin stack icon in gold #F59E0B
- Text: "Set a bounty to attract faster, better answers" in gold 13sp bold on first line + "Points will be deducted from your balance immediately" in muted gray 12sp on second line
- Right: current balance shown as "Balance: 340 🪙" in gold bold 13sp

TITLE FIELD:
- Label "Question Title" in muted gray 12sp above the field
- Dark fill input #161B22, 12dp rounded corners, border #30363D, 16dp padding inside
- Placeholder: "e.g. How do I solve bitmask DP problems?" in muted gray
- Character count bottom-right: "0/150" in muted gray 11sp
- No icon — the title field is wide and open

TAGS SELECTOR:
- Label "Tags" in muted gray 12sp above
- Tappable field showing selected tags as purple pills inside the field + a "+" icon on the right in purple
- Placeholder when empty: "Add up to 5 tags (e.g. DSA, Math)" in muted gray
- Below the field: a horizontally scrollable row of suggested quick-add tags: "DSA" "Math" "Physics" "Calculus" "Graph Theory" as outlined gray chips — tapping one adds it to the selected tags above

BODY EDITOR:
- Label "Description" in muted gray 12sp above
- EDITOR TOOLBAR (above the text area): dark bar #161B22 with border #30363D, horizontal scrollable row of formatting icons:
  - Bold B · Italic I · Code ` ` · Code block { } · Math formula Σ · Image 🖼 · Link 🔗
  - Each icon in muted gray, active/selected state turns purple
  - A divider line then: Camera icon button in purple with label "Scan Problem" — this triggers the AI image scanner
- BODY TEXT AREA: dark fill #161B22, min height 180dp, 12dp rounded corners, border #30363D, 14sp white text, line height 1.6, placeholder "Describe your problem in detail. You can use code blocks and math equations." in muted gray
- Below text area: character count "0/5000" muted gray 11sp right-aligned
- Code block preview example at the bottom of the text area showing how a code block looks when inserted — monospace font, cyan left border, dark bg

BOUNTY SECTION:
- Label "Set Bounty (optional)" in muted gray 12sp above
- Dark card #161B22, 12dp rounded corners, border #30363D, 16dp padding
- A horizontal slider: track is dark #30363D, filled portion is purple-to-cyan gradient, circular thumb is white with purple border and glow. Slider goes from 0 to 100 in steps of 5.
- Above slider: current value displayed large — "30" in bold white 28sp centered + "pts" in muted gray 16sp beside it
- Below slider: three preset quick-select buttons in a row: "10 pts" · "30 pts" · "50 pts" — outlined gray pills, tapping one snaps the slider to that value. Selected preset has purple fill.
- Bottom of card: "Remaining balance after posting: 310 🪙" in muted gray 12sp

AI DUPLICATE CHECK NOTICE:
- Shown below the bounty section as a slim info row
- Info icon in cyan + "We'll check for similar questions before posting" in muted gray 12sp

FIXED BOTTOM:
- Background #161B22, top border #30363D, 16dp padding
- Full width CTA button: gradient purple to cyan, "POST QUESTION" bold white 16sp, 12dp rounded corners, glow effect — disabled state (desaturated) when required fields empty
- Below button (inside safe area): "Your question will be visible to all users immediately" in muted gray 11sp centered

EXTRA DETAILS:
- The camera "Scan Problem" button in the toolbar should have a subtle purple glow to draw attention — this is a key differentiator feature
- When the user taps Scan Problem, show a bottom sheet design (half screen modal): dark #161B22 background, centered camera viewfinder box with purple corners, "Point camera at your problem" white 15sp, a circular capture button in purple gradient at the bottom
- Dot-grid background visible behind the form content at very low opacity
- When tags reach 5, the "+" icon becomes disabled (grayed out)
```

---

## Page 4 — Daily Challenge

```
Design a mobile Daily Challenge screen for QuestBoard, a dark-themed gamified STEM Q&A app. This screen shows today's coding problem fetched from Codeforces, lets users attempt and mark it as solved, and shows a leaderboard of fastest solvers.

VISUAL STYLE:
- Dark background #0D1117, same design system
- This screen should feel like a "daily mission" in a game — high stakes, time-sensitive energy
- Use gold #F59E0B more prominently here than other screens — gold = reward = challenge
- A subtle animated countdown or timer aesthetic (even if static in design)

FIXED TOP APP BAR:
- Background #161B22, bottom border #30363D
- Left: back arrow or hamburger in white
- Center: ⚡ lightning bolt icon in gold + "Daily Challenge" in bold white 16sp
- Right: calendar icon in muted gray showing today's date "Jul 7" in muted gray 11sp below it

HERO BANNER (below app bar, NOT scrollable):
- Full width, height approximately 160dp
- Background: dark gradient from #161B22 to #0D1117, with a radial gold glow effect in the top-right corner like a sunrise
- Left content:
  - Small label "TODAY'S QUEST" in gold #F59E0B bold 11sp uppercase with letter spacing
  - Challenge title "Balanced Subsequence" in bold white 22sp, max 2 lines
  - Row: difficulty badge + source badge
    - Difficulty badge: "Medium" — amber #F59E0B background at 20% opacity, amber text, 6dp rounded corners
    - Source badge: "Codeforces · 1234A" — muted gray outlined pill, muted gray text 12sp
- Right content:
  - Large gold coin stack illustration or trophy icon (60dp) with gold glow — represents the reward
  - Below it: "+50 🪙" in bold gold 20sp
  - "Bonus Points" in muted gray 11sp

TAB ROW (below hero, fixed):
- Two tabs: "Problem" (active) and "Leaderboard"
- Active tab: bold white 14sp + full-width underline in purple-to-cyan gradient, 3dp height
- Inactive tab: muted gray 14sp
- Background #161B22, bottom border #30363D

--- PROBLEM TAB (default active) ---

SCROLLABLE CONTENT:

STATUS CARD (top of scroll):
- Dark card #161B22, 12dp rounded corners, border #30363D, 16dp margin
- If not attempted: 
  - Center: shield icon in muted gray + "You haven't started yet" white 14sp + "Solve it to earn 50 bonus points" muted gray 13sp
  - A progress bar below: empty dark track, 0% filled
- If attempted but not solved (show this state in design):
  - Amber clock icon + "In Progress" in amber bold 14sp
  - Progress bar: 40% filled in amber gradient

PROBLEM STATEMENT CARD:
- Dark card #161B22, 12dp rounded corners, border #30363D, 16dp horizontal margin, 16dp padding
- "Problem Statement" label in muted gray 12sp uppercase bold at top
- Body text white 14sp line height 1.7 — sample problem text showing formatted content
- Constraints section: thin divider then "Constraints" label in muted gray 11sp uppercase + constraint text in monospace white 13sp
- Input/Output example blocks: dark #0D1117 background, 8dp rounded corners, cyan left border 3dp
  - "Input" label in cyan 11sp uppercase above each block
  - "Output" label in cyan 11sp uppercase above output block
  - Monospace text inside blocks

FIXED BOTTOM ACTION BAR:
- Background #161B22, top border #30363D, 16dp padding, safe area
- Two buttons side by side:
  - Left button (secondary): outlined border #30363D, "View on Codeforces ↗" in white 14sp, 12dp rounded corners — takes user to original problem
  - Right button (primary): gradient purple to cyan, "MARK AS SOLVED ✓" in bold white 14sp, glow effect, 12dp rounded corners
- Above the buttons: "🔥 12 users solved today" in muted gray 12sp centered

--- LEADERBOARD TAB ---

LEADERBOARD HEADER:
- "Today's Fastest Solvers" in bold white 16sp, 16dp padding
- Subtitle: "Race to the top for extra glory" in muted gray 13sp

TOP 3 PODIUM (special design for ranks 1, 2, 3):
- Three columns arranged as a podium: rank 2 left (shorter), rank 1 center (tallest), rank 3 right (shortest)
- Each column has: avatar circle (48dp for 1st, 40dp for 2nd and 3rd) + crown icon above avatar for 1st place in gold + username below in white 13sp + time solved below in muted gray 12sp
- Rank 1 platform: gold #F59E0B fill + "🥇 1" — tallest
- Rank 2 platform: silver #94A3B8 fill + "🥈 2"
- Rank 3 platform: amber/bronze #B45309 fill + "🥉 3"

REMAINING RANKS (list below podium):
- Each row: rank number muted gray 14sp + avatar 36dp + username white 14sp + "· Xh Xm" solve time muted gray 12sp + right side: gold coin + points earned in gold 13sp
- Alternating rows very slightly different background for readability
- Current user's row (if they solved): highlighted with purple left border 3dp + subtle purple background tint

EXTRA DETAILS:
- The hero banner's gold glow is the visual centrepiece of this screen — make it feel special and rewarding
- The podium design must feel like a real game leaderboard — bold, celebratory
- Dot-grid background throughout at very low opacity
- Empty leaderboard state (if no solvers yet): centered trophy outline icon in muted gold + "Be the first to solve today's challenge!" in white 15sp
```

---

## Page 5 — Leaderboard

```
Design a mobile Leaderboard screen for QuestBoard, a dark-themed gamified STEM Q&A app. This screen shows the top users ranked by points, with weekly and all-time tabs.

VISUAL STYLE:
- Dark background #0D1117, same design system
- This screen is the "hall of fame" — celebratory, prestigious, competitive
- Gold, silver, bronze color language is dominant here more than purple
- The top 3 users get special visual treatment — everyone else is a list

FIXED TOP APP BAR:
- Background #161B22, bottom border #30363D
- Center: trophy icon 🏆 in gold #F59E0B (20dp) + "Leaderboard" bold white 18sp beside it
- Right: a small "?" help icon in muted gray

PERIOD TAB ROW (below app bar, fixed):
- Two tabs: "This Week" (active) and "All Time"
- Active: bold white 14sp + full gradient underline purple-to-cyan 3dp
- Inactive: muted gray 14sp
- Background #161B22, bottom border #30363D

MY RANK BANNER (below tabs, fixed — does not scroll):
- Full width card, background: subtle purple gradient at 10% opacity, border purple #7C3AED at 40% opacity, 0dp rounded corners (edge to edge)
- Content: "Your Rank" label muted gray 11sp uppercase on left + large rank number "#24" in bold white 24sp
- Right side: avatar 36dp + "340 🪙" in gold bold 14sp + small up arrow in green if rank improved: "↑ 3 this week" in green 12sp
- This banner always shows the logged-in user's rank even if they're not in the top 20

TOP 3 PODIUM SECTION (scrollable content starts here):
- Podium layout showing rank 1 center elevated, rank 2 left, rank 3 right — same structure as Daily Challenge leaderboard but larger and more dramatic
- Background behind the podium: very subtle radial gold glow centered on rank 1, spreading outward, very low opacity — like stadium lights
- RANK 1 (center, tallest platform):
  - Avatar circle 64dp with a gold ring border (3dp) + gold crown icon floating above the avatar (20dp)
  - Username below avatar: bold white 16sp
  - Points: gold coin icon + points in bold gold 18sp
  - Platform: gold #F59E0B gradient block, tallest (80dp height), rounded top corners
  - "🥇" emoji on platform
- RANK 2 (left, medium height platform):
  - Avatar 52dp with silver ring border
  - Username white 14sp
  - Points in silver/white 15sp
  - Platform: silver #94A3B8 gradient block, 64dp height
  - "🥈" emoji
- RANK 3 (right, shortest platform):
  - Avatar 52dp with bronze ring border
  - Username white 14sp
  - Points in amber/white 15sp  
  - Platform: bronze #B45309 gradient block, 52dp height
  - "🥉" emoji

RANKS 4 AND BELOW (list, scrollable):
- Section label: "Rankings" in muted gray 12sp uppercase + total count "· 1,248 users" muted gray right-aligned — 16dp padding
- Each rank row is a card #161B22, 10dp rounded corners, border #30363D, 12dp padding, 8dp gap between rows, 16dp horizontal margin

  ROW ANATOMY:
  - Left: rank number "#4" bold white 16sp in a fixed 36dp width column
  - Avatar: 44dp circle with colored ring (no special ring for ranks 4+)
  - Center column: username bold white 14sp on top + "Level 7" + tag badge of their top tag (e.g., "DSA" small purple chip) in muted gray 12sp below
  - Right column: gold coin icon + point total bold gold 14sp on top + rank change indicator below: "↑5" in green 12sp if up, "↓2" in red if down, "—" in muted gray if no change

  SPECIAL ROW STATES:
  - Current user's row: purple left border 3dp + background purple tint at 8% + "You" label in purple 11sp beside username
  - Top 10 rows: a very subtle gold shimmer or glow on the left edge of the card

WEEKLY STATS STRIP (between podium and list):
- Horizontal scrollable strip of 3 mini-stat cards, each #161B22, 10dp rounded corners, border #30363D, 12dp padding:
  - "Total Questions" — question icon in purple + "1,248" bold white 18sp + "this week" muted gray 11sp
  - "Bounties Awarded" — gold coin icon + "340 🪙" bold gold 18sp + "distributed" muted gray 11sp
  - "Top Helper" — crown icon in gold + "rifat_22" bold white 14sp + "52 answers" muted gray 11sp

BOTTOM NAVIGATION BAR:
- Background #161B22, top border #30363D
- Five tabs: Home · Challenges · (FAB space) · Leaderboard (ACTIVE — trophy icon filled purple, label in purple) · Profile
- Same structure as Home Feed bottom nav

EXTRA DETAILS:
- The podium section is the visual hero of this screen — spend design effort here
- The gold radial glow behind rank 1 is subtle but important — gives a "spotlight on the champion" feel
- Rank change arrows (↑ / ↓) are small but meaningful — always show them
- Loading skeleton state: show gray animated shimmer placeholder rows while data loads
- Empty state (no data yet): centered empty trophy outline in muted gold + "No rankings yet this week. Be the first!" white 15sp
- Dot-grid background throughout at very low opacity
- Status bar white icons
```

---

## Notes for Next Pages

The following pages will be added to this file in upcoming sessions:

- **User Profile** — stats overview, badge grid, streak flame, question and answer history tabs
- **Notifications** — notification list with type icons, unread badges, mark all read
- **Settings** — change password, notification preferences, about
- **Post Answer** — answer editor with code/math formatting toolbar
- **AI Hint Modal** — bottom sheet showing hint request, cost warning, hint result card