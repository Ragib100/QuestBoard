# Task board

Single source of truth for progress. Check a box only when it meets the definition of
done in [docs/product.md](docs/product.md#definition-of-done). Work top to bottom —
milestones are ordered by dependency, not preference.

**Now:** M2 — the core loop. Nothing in M3+ starts until M2 is done.

| Milestone | Status |
|---|---|
| M0 · Foundation | ✅ done |
| M1 · Auth & profiles | 🟡 mostly done |
| M2 · Quest loop (MVP core) | 🔴 not started |
| M3 · Gamification & notifications | 🔴 not started |
| M4 · AI & daily challenge | 🔴 not started |
| M5 · Search, admin & polish | 🔴 not started |
| M6 · Ship | 🔴 not started |

---

## M0 · Foundation ✅

- [x] Repo, branch rules, `.env.example` for client and server
- [x] FastAPI app with `/api` router, Supabase + SQLAlchemy wired
- [x] `get_current_user_id` JWT dependency + `GET /api/ping`
- [x] Flutter app: theme, deep links, Supabase init
- [x] Docs reorganised — `CLAUDE.md`, `docs/`, this board

## M1 · Auth & profiles 🟡

- [x] Login, signup, email verification, forgot/reset password — UI and wiring
- [x] `users` table and model
- [x] `POST /api/users` + `ProfileCreate` onboarding screen
- [x] Avatar upload to the `profile_image` bucket
- [ ] `GET /api/users/{id}` — profile read
- [ ] `PATCH /api/users/{id}` — profile edit
- [ ] Wire `profile_screen.dart` and `profile_edit.dart` to those endpoints (currently static)
- [ ] Migration: add `users.is_admin BOOLEAN NOT NULL DEFAULT false`
- [ ] Fix `main.dart` app title — says `QuestHub`, should be `QuestBoard`
- [ ] Route users with a session but no `users` row to `ProfileCreate` on cold start

## M2 · Quest loop 🔴

The product does not exist until this works end to end.

**Database**
- [ ] Migration: `quests` gains `bounty_points`, `is_solved`, `accepted_answer_id`
- [ ] Create `answers`, `votes`, `point_transactions` (see [docs/data-model.md](docs/data-model.md))

**Server**
- [ ] `GET /api/quests` — pagination, `tag` filter, `sort=latest|bounty|votes`
- [ ] `GET /api/quests/{id}` — quest + answers + vote state
- [ ] `PATCH` / `DELETE /api/quests/{id}` — author only, refund on delete
- [ ] Deduct the bounty inside `POST /api/quests`, reject when the balance is short
- [ ] `POST /api/quests/{id}/answers`
- [ ] `PATCH` / `DELETE /api/answers/{id}`
- [ ] `POST /api/answers/{id}/accept` — the bounty transfer transaction
- [ ] Vote endpoints for quests and answers, with toggle logic and ±1 to the author
- [ ] `PointService` — the one place `users.points` and `point_transactions` are written

**Client**
- [ ] `QuestService` (list, get, create, update, delete) on the `UserService` pattern
- [ ] Wire `browse_questions.dart` — real data, pagination, loading/error/empty states
- [ ] Wire `question_detail.dart` — answers, accept button for the author
- [ ] Wire `ask_question.dart` — tags, bounty slider, balance check before submit
- [ ] Answer composer sheet
- [ ] Vote buttons with optimistic update and rollback on failure
- [ ] Points balance in the app bar, refreshed after every economy action
- [ ] Markdown + code block + LaTeX rendering for quest and answer bodies

## M3 · Gamification & notifications 🔴

- [ ] Create `notifications`, `badges`, `user_badges`; seed the badge catalogue
- [ ] Streak update + `daily_bonus` on first activity of the day
- [ ] Badge check as a background task after each point event
- [ ] `GET /api/leaderboard` (weekly + all-time) and `GET /api/badges`
- [ ] Notification rows on answer received / accepted / bounty won / badge earned
- [ ] Notification list + read endpoints
- [ ] Wire `leaderboard_screen.dart` and `notifications_screen.dart`
- [ ] Unread badge on the nav bell
- [ ] Badges and streak on the profile screen

## M4 · AI & daily challenge 🔴

- [ ] Pick and configure the LLM provider; add the key to `.env.example`
- [ ] Create `ai_hints`; write the Socratic prompt (hints only, never the answer)
- [ ] `POST /api/ai/hint` — deduct 5 points, refund on failure, 3/hour rate limit
- [ ] Hint modal in `question_detail.dart` with the point-cost confirmation
- [ ] Create `daily_challenges`, `challenge_attempts`
- [ ] Daily job pulling one Codeforces problem, with a cached fallback
- [ ] Codeforces handle verification flow
- [ ] `GET /api/challenges/today`, `POST /solve`, `GET /leaderboard`
- [ ] Wire `daily_challenge_screen.dart`

## M5 · Search, admin & polish 🔴

- [ ] Enable `pg_trgm`, add the GIN indexes
- [ ] `GET /api/quests/search` + search UI in the web top bar and mobile feed
- [ ] Tag filter chips and sort control on the feed
- [ ] Admin endpoints: stats, user list, suspend, force-delete
- [ ] Wire the five screens in `client/lib/app/admin/`, gated on `is_admin`
- [ ] Audit every screen for loading / error / empty states
- [ ] Never surface a raw exception — always the API's `detail`

## M6 · Ship 🔴

- [ ] Deploy the API (Render or Railway) and point `API_URL` at it
- [ ] Release Android APK, tested off a debug build
- [ ] Web build deployed
- [ ] Seed demo data
- [ ] Backend tests for the economy transactions (bounty transfer, voting)
- [ ] Final report and demo recording

---

## Chores

- [ ] `client/ios/` and `client/macos/` are untracked and unused — delete them or
      gitignore them; a previous commit removed them and they came back
- [ ] `server/.ruff_cache/` is gitignored but present locally
- [ ] CI: `flutter analyze` + `ruff check` on every PR
