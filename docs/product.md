# Product

**QuestBoard** is a gamified Q&A app for STEM students (math, physics, CS). Unlike a
generic Q&A site it runs a closed **point economy**: asking costs points, helping earns
them. AI is deliberately a *hint* system, not an answer machine — the product exists to
make students learn, not copy.

**Primary user:** an undergraduate stuck on a problem set at 11pm who wants a nudge, and
the classmate who enjoys being the one who explains it.

## Point economy

The single source of truth for every number in the app. Every balance change writes a
row to `point_transactions` — the `users.points` column is a cache of that ledger, never
edited on its own.

| Event | Δ points | `reason` |
|---|---|---|
| Complete profile after signup | +100 | `signup_bonus` |
| Post a quest with a bounty | −bounty (immediately) | `bounty_posted` |
| Your answer is accepted | +bounty | `bounty_awarded` |
| Your content is upvoted | +1 | `vote_received` |
| Your content is downvoted | −1 | `vote_lost` |
| First activity of the day | +10 | `daily_bonus` |
| Solve the daily challenge | +50 | `challenge_solved` |
| Request an AI hint | −5 | `ai_hint` |

Rules: balance can never go below 0 — reject the action instead. Bounty is 0–100 and is
deducted at post time, so an unanswered quest's points stay locked until it is answered
or cancelled. AI hints are rate-limited to 3/hour/user. Hint points are deducted before
the LLM call and refunded in the same transaction if the call fails.

## Scope

### Tier 1 — MVP. Nothing in Tier 2 starts until all of this works.
1. **Auth & profiles** — Supabase email/password, verification, reset. Profile with
   avatar, points, streak, Codeforces handle.
2. **Quests & answers** — post, browse, answer, accept. Markdown + code blocks + LaTeX.
3. **Bounty transfer** — accepting an answer moves points in one DB transaction.
4. **Voting** — up/down on quests and answers, ±1 point to the author.
5. **Feed basics** — tag filter, sort by latest / bounty / votes.

### Tier 2 — Engagement. Build in this order.
6. **Gamification** — leaderboard (weekly + all-time), daily streaks, auto-awarded badges.
7. **In-app notifications** — answer received, answer accepted, badge earned, bounty won.
8. **AI hint mentor** — 5 points for a Socratic hint. Prompted to ask guiding questions,
   never to give the answer.
9. **Daily challenge** — one Codeforces problem per day, +50 points, per-day leaderboard.
   Users link a Codeforces handle on their profile to verify solves.
10. **Search** — Postgres `pg_trgm` similarity over quest titles and bodies.
11. **Admin** — stats, user suspend, force-delete content. UI already exists.

### Tier 3 — Only if Tiers 1 and 2 are done and tested.
12. **Duplicate detection** — warn before posting a near-identical quest (reuses the
    `pg_trgm` index from search, so it is nearly free once search ships).
13. **AI problem scanner** — photograph a printed problem, OCR it into the post form.

### Explicitly out of scope
Live discussion rooms / WebSocket chat · in-app code runner (Judge0/Piston) ·
personalized AI study paths · automatic difficulty grading · follow system and social
feed · push notifications (FCM) · iOS builds.

These were specced early and cut — see [decisions.md](decisions.md) D5 and D7. Do not
re-add one without deleting something else.

## Badges

Checked inline, in the same transaction as the event that earned them — three
cheap counts, and a badge can never be lost to a background worker dying.

Each row's condition is also its `badges.description` in the database, and the
profile prints that under the badge whether it is earned or not, so the list
doubles as the explanation (decisions.md D50).

| Badge | Condition |
|---|---|
| `first_answer` | posted ≥ 1 answer |
| `first_bounty` | won ≥ 1 bounty |
| `bounty_hunter` | won ≥ 10 bounties |
| `streak_5` / `streak_30` | `streak_days` ≥ 5 / 30 |
| `challenger` | solved ≥ 7 daily challenges |
| `ai_skeptic` | an accepted answer on a quest you bought no AI hint for |
| `top_helper` | top 10 on the weekly leaderboard — **not awarded yet**, it needs a scheduled rank check (TASKS.md) |

## Definition of done

A feature ships when: the endpoint returns correct data for valid input and correct
status codes for invalid input; the screen renders it and handles loading, error and
empty states; it has been run end-to-end on a real device; and the PR is reviewed.
