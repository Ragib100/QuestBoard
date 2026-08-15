# Demo recording script

A shot-by-shot plan for the ~5 minute project demo. Ordered so each shot sets up
the next, and so the two things a marker actually rewards — **it works on a real
phone** and **the economy is provably correct** — both land.

The written companion is the final report (published separately). Rule for the whole
recording, same as ground rule 4: **show real data**. Do not stage a screen the app
cannot actually produce.

## Before you record

```bash
# 1. Server must be awake — Render free tier sleeps. Hit it and wait for 200.
curl -s https://questboard-mccq.onrender.com/api/ | head

# 2. Fresh release build on the phone, so the launcher icon and splash are real
cd client
flutter build apk --release --split-per-abi
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# 3. Green light on the checks you are about to claim
flutter analyze && flutter test
cd ../server && source .venv/bin/activate && pytest && ruff check app && black --check app
```

Seed state you need in the database beforehand — **do this before recording**, so no
shot involves waiting on an empty screen:

- At least **6 users with points**, so the leaderboard has a full podium plus rows.
- At least **8 quests**, two of them solved, with varied tags and bounties.
- One quest with **2–3 answers** that your demo account did *not* write, and which
  your demo account **owns**, so you can accept an answer on camera.
- Your demo account's **Codeforces handle verified**, and the daily challenge
  **unclaimed** — the claim is a one-shot moment and you cannot re-record it on the
  same account the same day. Keep a second verified account in reserve.
- An **admin account** for the final shot.

## Recording

Phone screen, cabled, no audio from the device:

```bash
# scrcpy mirrors the device; record the mirror
scrcpy --record=demo-raw.mp4 --max-size=1080 --stay-awake
```

Or record on-device (Android 11+: quick-settings tile → Screen record) and pull it:

```bash
adb pull /sdcard/Movies/screen-recording.mp4 demo-raw.mp4
```

Narrate separately and mix, rather than talking over a live take — you will need
several attempts at the accept and claim shots, and re-recording narration each time
wastes the evening.

```bash
# Trim and normalise for submission
ffmpeg -i demo-raw.mp4 -ss 00:00:02 -c:v libx264 -crf 20 -preset slow \
       -c:a aac -b:a 128k demo.mp4
```

---

## Shot list

Times are cumulative targets, not hard cuts.

### 1 · Cold launch — 0:00–0:20
**Do:** Home screen of the phone, tap the QuestBoard icon, let it open on its own.

**Say:** "QuestBoard is a Q&A board for STEM students, built as a Flutter app on a
FastAPI server. This is a release build on a real device."

**Why this shot is first:** it is the only one that proves the app is installed
software rather than a laptop demo. Let the launcher icon and splash play — do not
cut them.

### 2 · Sign in — 0:20–0:35
**Do:** Sign in. Let the password manager offer to fill.

**Say:** "Authentication goes to Supabase directly. Our server never issues tokens —
it verifies the bearer JWT on every request."

### 3 · Dashboard — 0:35–1:00
**Do:** Land on the dashboard. Let the stat tiles count up. Scroll slowly through
recent quests.

**Say:** "Points, streak and badge counts are live from the API — the dashboard has
no hardcoded numbers in it."

### 4 · Browse and search — 1:00–1:35
**Do:** Open Browse. **Pull to refresh** so the skeletons show. Type a search term.
Switch the sort to Bounty. Tap a tag filter.

**Say:** "Search is a Postgres trigram match ranked title-first, with tag filtering
and three sort orders — all one endpoint, so paging and vote counts stay consistent."

**Watch for:** let the skeleton placeholders be visible for a beat. They read as
polish and they are on screen anyway.

### 5 · The accept — 1:35–2:25 · **the most important shot**
**Do:** Open a quest you own that has answers. Scroll through the answers. Tap
Accept. Confirm the dialog — **pause on it long enough to read** — then let the
celebration play.

**Say:** "Accepting transfers the bounty from me to the author of the answer. That
happens in a single database transaction: my balance drops, theirs rises, and two
rows go into the ledger. If any part fails, none of it happens."

**Watch for:** the confirmation dialog names the exact number of points and the
recipient. Let the marker read it.

### 6 · Points, proven — 2:25–3:00
**Do:** Go to Profile. Show the earned-vs-spent bar, then scroll the point history.
Point at the row the accept just created.

**Say:** "Every balance change in the system is one row here. Nothing else in the
codebase is allowed to write to a user's point total."

### 7 · Leaderboard — 3:00–3:20
**Do:** Open Leaderboard. Let the podium rise. Switch to This Week.

**Say:** "The weekly board is summed from the ledger over a trailing seven days —
there is no cron job and no snapshot table, so it cannot drift out of sync."

### 8 · Daily challenge — 3:20–4:00
**Do:** Open the Daily Challenge. Show the problem and the Codeforces link. Tap
Claim. Let the celebration play.

**Say:** "This is a real Codeforces problem. Claiming does not take my word for it —
the server checks my public submissions for an accepted verdict on this exact
problem, which is why the handle has to be verified first."

### 9 · AI hint — 4:00–4:25
**Do:** Open an unsolved quest. Tap the hint button. **Pause on the cost dialog.**
Confirm, wait for the hint.

**Say:** "Hints cost points and are rate-limited. The points come out before the
model is called and go back in the same transaction if the call fails — a provider
outage can never charge a student."

### 10 · Admin and the closed economy — 4:25–5:00 · **the closing argument**
**Do:** Sign in as admin. Open the admin dashboard. Rest on the **points in
circulation** card.

**Say:** "This number is the whole design. Points are never minted and never
destroyed, only moved — so every transfer writes a balanced pair of ledger rows.
Our server test suite asserts the ledger sums to zero. That is the one property we
most wanted to be able to prove, and we can."

**End on this card.** It is the strongest frame in the recording.

---

## If you have 30 more seconds

Show the app at a large system text scale (Settings → Display → Font size → largest),
then re-open Browse and the Leaderboard. Nothing overflows, because every list screen
is tested at 320 px and 360 px wide across text scales up to 2×. Very few student
projects can survive that on camera.

## Do not film

- The `.env` files, or any screen showing a key or connection string.
- Real classmates' names or avatars without asking them first.
- A cold Render request — the free tier's first response after sleeping can take
  30 seconds and it will look like a hang. Warm it up beforehand (see above).
