# QuestBoard — 10 Week Project Plan

**Project:** QuestBoard — A Gamified Q&A Platform for STEM Problem Solving  
**Team:** Group A5 (4 members)  
**Duration:** 10 Weeks  
**Stack:** Flutter · FastAPI · Supabase PostgreSQL · Supabase Auth · Supabase Storage · Firebase

---

## Team Roles

| Member | Primary Role |
|---|---|
| Md. Saif Ahmed (202314008) | Backend Lead — FastAPI, DB, AI endpoints |
| Md. Ragib Hossain Rifat (202314022) | Backend — DB schema, auth, gamification |
| Md. Ekram Hossen (202314032) | Frontend Lead — Flutter, screens, navigation |
| Mohammad Arafat Hasan Sarker (202314069) | Frontend — UI components, state management |

> Role split is a guide, not a wall. Both backend members should review each other's PRs, and both frontend members should understand the API contracts they are consuming.

---

## Ground Rules

- **GitHub:** One repository, `main` branch is always deployable. Feature branches only — never commit directly to `main`.
- **PR rule:** Every feature needs at least one review from another member before merging.
- **Daily standups:** 15 minutes each day. What did I do yesterday? What am I doing today? Any blockers?
- **API contract first:** Backend defines the request/response shape in `api.md` before Frontend starts building a screen. Frontend should never be blocked waiting to guess the shape.
- **No gold plating:** Do not start a Better or Next Level feature until all Must features pass basic testing.

---

## Milestone Overview

| Week | Theme | Deliverable |
|---|---|---|
| 1 | Foundation | Repo setup, DB live, auth working |
| 2 | Core backend | Questions & answers CRUD API |
| 3 | Core frontend | Auth screens + Q&A feed UI |
| 4 | Economy | Voting, points, bounty transfer |
| 5 | AI & Challenges | AI hint endpoint + daily challenge |
| 6 | Frontend catch-up | All Must screens complete |
| 7 | Better features — backend | Gamification, notifications, search |
| 8 | Better features — frontend | Leaderboard, notifications, search UI |
| 9 | Polish & testing | Bug fixes, edge cases, performance |
| 10 | Final submission | Report, demo prep, deployment |

---

## Week 1 — Foundation

**Theme:** Get the skeleton working end-to-end before writing any feature code.

**Goal by end of week:** A Flutter app that can register a user, log in, and hit one protected FastAPI endpoint successfully.

---

### Backend (Saif + Rifat)

**Day 1–2**
- [ ] Create GitHub repository, set up branch protection on `main`
- [ ] Initialize FastAPI project structure:
  ```
  backend/
    main.py
    routers/
    models/
    schemas/
    dependencies/
    config.py
    requirements.txt
  ```
- [ ] Set up `.env` for Supabase URL, Supabase anon key, Supabase service key
- [ ] Connect FastAPI to Supabase PostgreSQL using `asyncpg` or `supabase-py`

**Day 3–4**
- [ ] Run the full `schema.sql` from `db.md` in Supabase SQL Editor
- [ ] Verify all 13 tables created, triggers firing, seed data inserted
- [ ] Write the JWT verification dependency in FastAPI:
  ```python
  # dependencies/auth.py
  def get_current_user(token = Depends(HTTPBearer())):
      payload = jwt.decode(token.credentials, ...)
      return payload["sub"]  # user uuid
  ```
- [ ] Write a test protected endpoint `GET /api/ping` that returns the authenticated user's id

**Day 5**
- [ ] Deploy FastAPI to a free host (Railway or Render)
- [ ] Confirm the deployed URL works from Postman
- [ ] Document the base URL in the team's shared notes

---

### Frontend (Ekram + Arafat)

**Day 1–2**
- [ ] Initialize Flutter project
- [ ] Add dependencies to `pubspec.yaml`:
  ```yaml
  supabase_flutter: ^2.0.0
  go_router: ^13.0.0
  flutter_riverpod: ^2.5.0
  dio: ^5.4.0
  ```
- [ ] Set up project structure:
  ```
  lib/
    main.dart
    core/
      router/
      theme/
      constants/
    features/
      auth/
      questions/
      answers/
      profile/
    shared/
      widgets/
      models/
  ```
- [ ] Configure Supabase in `main.dart` with project URL and anon key

**Day 3–4**
- [ ] Build Login screen UI (email + password fields, login button)
- [ ] Build Register screen UI (username + email + password)
- [ ] Wire Supabase Auth: `signUp()` and `signInWithPassword()`
- [ ] Set up `go_router` with auth guard (redirect to login if no session)

**Day 5**
- [ ] Test full flow: Register → verify email → login → hit `GET /api/ping` → see user id in response
- [ ] Build Forgot Password screen (calls `resetPasswordForEmail()`)
- [ ] Commit everything, open PR, review, merge

**End of Week 1 Checklist:**
- [ ] DB live on Supabase with all tables
- [ ] FastAPI deployed and reachable
- [ ] Flutter app can register, verify email, and log in
- [ ] Protected endpoint returns correct user id from JWT

---

## Week 2 — Core Backend

**Theme:** Build all Must-tier API endpoints for questions and answers. Frontend can mock data this week.

**Goal by end of week:** Postman can successfully call every question and answer endpoint with a real JWT.

---

### Backend (Saif + Rifat)

**Day 1–2 — Questions CRUD**
- [ ] `GET /api/questions` — list with pagination (page, limit)
- [ ] `POST /api/questions` — create with tags and bounty
  - Deduct bounty from `users.points` in a transaction
  - Insert `question_tags` rows
  - Log `point_transactions` with `reason = 'bounty_posted'`
- [ ] `GET /api/questions/{id}` — fetch with answers
- [ ] `PATCH /api/questions/{id}` — author only
- [ ] `DELETE /api/questions/{id}` — author only, unsolved only

**Day 3 — Answers CRUD**
- [ ] `GET /api/questions/{id}/answers`
- [ ] `POST /api/questions/{id}/answers`
- [ ] `PATCH /api/answers/{id}` — author only
- [ ] `DELETE /api/answers/{id}` — author only, not accepted

**Day 4 — Accept answer + bounty transfer**
- [ ] `POST /api/answers/{id}/accept`
  - Wrap in DB transaction:
    1. Set `answers.is_accepted = true`
    2. Set `questions.is_solved = true`, `accepted_answer_id`
    3. Add bounty to helper's `users.points`
    4. Log `point_transactions` with `reason = 'bounty_awarded'`
    5. Insert `notifications` row for helper

**Day 5**
- [ ] Write Pydantic schemas for all request/response models
- [ ] Add input validation (title min length, bounty ≥ 0, body not empty)
- [ ] Test all endpoints in Postman with valid and invalid inputs
- [ ] Commit, PR, review, merge

---

### Frontend (Ekram + Arafat)

**Day 1–2**
- [ ] Build API client using `dio` with base URL and auth interceptor:
  ```dart
  // Attach Supabase token to every request automatically
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = supabase.auth.currentSession?.accessToken;
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    }
  ));
  ```
- [ ] Create data models (`Question`, `Answer`, `User`) with `fromJson`

**Day 3–5**
- [ ] Build Home Feed screen with hardcoded mock data (real API next week)
- [ ] Build Question Detail screen skeleton (title, body placeholder, answers list placeholder)
- [ ] Build Post Question form screen (title, body, tags multi-select, bounty slider)
- [ ] Set up Riverpod providers for auth state

**End of Week 2 Checklist:**
- [ ] All question and answer endpoints working in Postman
- [ ] Bounty transfer tested — check `point_transactions` table has correct rows
- [ ] Flutter has Home Feed, Question Detail, Post Question screens (mock data OK)

---

## Week 3 — Core Frontend

**Theme:** Connect the Flutter app to the real backend. Users can post and read questions.

**Goal by end of week:** A real user can register, post a question with a bounty, and see it appear in the feed.

---

### Backend (Saif + Rifat)

**Day 1–2**
- [ ] `GET /api/users/{id}` — public profile
- [ ] `PATCH /api/users/{id}` — update username, bio, avatar
- [ ] `GET /api/users/{id}/points` — balance + recent transactions
- [ ] Set up Supabase Storage buckets: `avatars`, `question-images`, `badges`
- [ ] Write storage upload helper for avatar images

**Day 3–5**
- [ ] Write error handling middleware — all errors return consistent JSON:
  ```json
  { "error": "message", "code": "ERROR_CODE" }
  ```
- [ ] Add request logging
- [ ] Write basic unit tests for the bounty transfer transaction
- [ ] Review and fix any issues found from Week 2

---

### Frontend (Ekram + Arafat)

**Day 1–2**
- [ ] Connect Home Feed to `GET /api/questions` — replace mock data
- [ ] Implement infinite scroll / pagination
- [ ] Connect Post Question form to `POST /api/questions`
- [ ] Show success/error toasts after posting

**Day 3–4**
- [ ] Connect Question Detail to `GET /api/questions/{id}`
- [ ] Show answers list
- [ ] Connect Post Answer form to `POST /api/questions/{id}/answers`
- [ ] Connect Accept Answer button to `POST /api/answers/{id}/accept`

**Day 5**
- [ ] Build User Profile screen connected to `GET /api/users/{id}`
- [ ] Show username, bio, points balance, question/answer history
- [ ] Build Edit Profile screen connected to `PATCH /api/users/{id}`
- [ ] Avatar upload to Supabase Storage

**End of Week 3 Checklist:**
- [ ] Full Q&A flow working end-to-end on a real device
- [ ] Bounty deducted on question post, awarded on answer accept
- [ ] User profile visible and editable

---

## Week 4 — Economy & Voting

**Theme:** Complete the points economy with voting. The gamified core of QuestBoard is fully working by end of this week.

**Goal by end of week:** Users can vote, points flow correctly for all actions, and the point ledger is accurate.

---

### Backend (Saif + Rifat)

**Day 1–2 — Voting endpoints**
- [ ] `POST /api/questions/{id}/vote`
  - Upsert into `votes` table
  - Toggle: same value removes, opposite value updates
  - Award/deduct 1 point to content author via `point_transactions`
- [ ] `POST /api/answers/{id}/vote` — same logic

**Day 3 — Points ledger validation**
- [ ] Write a DB function to verify `users.points` matches the sum of `point_transactions.amount` for every user
- [ ] Run it — fix any discrepancies found
- [ ] Add a check at the start of every point-spending endpoint: if balance < cost, return `402`

**Day 4–5**
- [ ] `GET /api/users/{id}/points` — include full transaction history
- [ ] Add `view_count` increment on `GET /api/questions/{id}` (use `UPDATE ... SET view_count = view_count + 1`)
- [ ] Comprehensive Postman testing of all economy flows

---

### Frontend (Ekram + Arafat)

**Day 1–2**
- [ ] Add upvote/downvote buttons to Question Detail screen
- [ ] Connect to `POST /api/questions/{id}/vote`
- [ ] Add upvote/downvote buttons to each answer card
- [ ] Connect to `POST /api/answers/{id}/vote`
- [ ] Optimistic UI update — change vote count immediately, revert on error

**Day 3–4**
- [ ] Add points balance display to the app bar / profile tab
- [ ] Build Points History screen — list of `point_transactions`
- [ ] Show bounty badge on question cards in the feed
- [ ] Color-code: green for earned, red for spent

**Day 5**
- [ ] Test voting toggle behavior
- [ ] Test insufficient points error — show correct message to user
- [ ] Fix any UI/UX issues found during team testing

**End of Week 4 Checklist:**
- [ ] Voting works with toggle and point adjustments
- [ ] Points balance always accurate
- [ ] Bounty visible on question cards
- [ ] Points history screen working

---

## Week 5 — AI & Daily Challenge

**Theme:** Add the two features that make QuestBoard unique — the AI hint and the daily coding challenge.

**Goal by end of week:** Users can request AI hints and attempt daily challenges, both affecting their point balance.

---

### Backend (Saif + Rifat)

**Day 1–2 — AI Hint endpoint**
- [ ] `POST /api/ai/hint`
  - Check balance ≥ 5, return `402` if not
  - Deduct 5 points + log transaction (inside try block)
  - Call LLM API with Socratic system prompt
  - Save hint to `ai_hints`
  - If LLM fails, refund points in except block
- [ ] Set up LLM API key in `.env` (use Claude or OpenAI)
- [ ] Rate limit: block if `COUNT(ai_hints WHERE user_id=X AND question_id=Y AND created_at > now()-1hr) >= 3`

**Day 3–4 — Daily Challenge**
- [ ] Write Codeforces API fetch function:
  ```python
  # Fetches a problem list and picks one by difficulty
  GET https://codeforces.com/api/problemset.problems
  ```
- [ ] `POST /api/challenges/fetch` — internal endpoint (called by cron only, protected by secret header)
- [ ] Set up cron job on Railway/Render to call this at midnight daily
- [ ] `GET /api/challenges/today`
- [ ] `POST /api/challenges/{id}/attempt`
- [ ] `POST /api/challenges/{id}/solve` — award bonus points, update streak

**Day 5**
- [ ] Test AI hint with valid and insufficient balance
- [ ] Test rate limiting (request 4 hints in a row)
- [ ] Manually test challenge flow end-to-end in Postman

---

### Frontend (Ekram + Arafat)

**Day 1–2 — AI Hint UI**
- [ ] Add "Get AI Hint" button to Question Detail screen
- [ ] Show point cost warning before confirming: "This will cost 5 points"
- [ ] Connect to `POST /api/ai/hint`
- [ ] Display hint in a styled card below the question body
- [ ] Show previous hints for this question (from `ai_hints`)

**Day 3–5 — Daily Challenge screen**
- [ ] Build Daily Challenge screen:
  - Problem title and full statement
  - Difficulty badge
  - Bonus points badge
  - "Start Challenge" button → calls `POST /api/challenges/{id}/attempt`
  - "Mark as Solved" button → calls `POST /api/challenges/{id}/solve`
- [ ] Build Past Challenges list screen connected to `GET /api/challenges`
- [ ] Show solve count and user's own attempt status on each challenge card

**End of Week 5 Checklist:**
- [ ] AI hint working with point deduction and rate limiting
- [ ] Daily challenge visible and solvable
- [ ] Points awarded correctly for challenge solve
- [ ] Streak increments after first activity of the day

---

## Week 6 — Frontend Catch-Up & Must Polish

**Theme:** Close all remaining UI gaps. Every Must feature should have a complete, usable screen by end of this week. No half-built screens.

**Goal by end of week:** A complete MVP — every Must feature working front-to-back, tested on a real device.

---

### Backend (Saif + Rifat)

**Day 1–2**
- [ ] Forgot password and change password flows — confirm they work with Supabase Auth deep link setup
- [ ] Add missing validations found during Week 5 testing
- [ ] Clean up any `TODO` comments in the codebase

**Day 3–5**
- [ ] Write integration tests for the 5 most critical flows:
  1. Register → post question with bounty → answer → accept → verify points transferred
  2. Vote up → check point awarded → vote again → check point removed
  3. Request AI hint → check deducted → request 4th hint → check blocked
  4. Solve daily challenge → check bonus points → check streak incremented
  5. Post question with more bounty than balance → check blocked
- [ ] Fix all bugs found

---

### Frontend (Ekram + Arafat)

**Day 1–2**
- [ ] Build Change Password screen using `supabase.auth.updateUser()`
- [ ] Add empty states to all list screens (no questions yet, no answers yet)
- [ ] Add loading spinners to all async actions
- [ ] Add pull-to-refresh on Home Feed and Question Detail

**Day 3–4**
- [ ] Fix all navigation edge cases (back button behavior, deep links)
- [ ] Make all screens responsive (test on small and large phone screens)
- [ ] Add form validation messages (title too short, body empty, etc.)

**Day 5**
- [ ] Full end-to-end test as a real user on a physical device
- [ ] List all bugs found → assign and fix immediately
- [ ] Tag the repo: `v1.0-mvp`

**End of Week 6 Checklist:**
- [ ] All Must features working on a real device
- [ ] No crashes on happy path flows
- [ ] Repo tagged `v1.0-mvp`
- [ ] Integration tests passing

---

## Week 7 — Better Features: Backend

**Theme:** Build the backend for all Better-tier features. Frontend picks these up in Week 8.

**Goal by end of week:** All Better-tier endpoints working and tested in Postman.

---

### Backend (Saif + Rifat)

**Day 1 — Search & Filtering**
- [ ] `GET /api/questions?tag=dsa&sort=bounty&solved=false`
- [ ] `GET /api/questions/search?q=bitmask` using `pg_trgm` similarity
- [ ] `GET /api/tags`

**Day 2 — Gamification**
- [ ] `GET /api/leaderboard?period=weekly`
- [ ] `GET /api/leaderboard?period=all`
- [ ] `GET /api/badges`
- [ ] `GET /api/users/{id}/badges`
- [ ] `GET /api/users/{id}/streak`
- [ ] Badge-check background task — runs after: answer accepted, challenge solved, streak updated

**Day 3 — Notifications**
- [ ] `GET /api/notifications`
- [ ] `PATCH /api/notifications/{id}/read`
- [ ] `PATCH /api/notifications/read-all`
- [ ] Make sure notification rows are inserted by all triggering events (answer posted, accepted, badge, vote)

**Day 4 — Push Notifications**
- [ ] Set up Firebase Admin SDK on FastAPI
- [ ] `POST /api/notifications/fcm-token` — store device token
- [ ] Send push notification alongside every in-app notification insert

**Day 5 — AI Scanner + Duplicate Check**
- [ ] `POST /api/ai/scan` — multipart image upload → Vision API → return extracted text
- [ ] `POST /api/ai/duplicate-check` — `pg_trgm` similarity on questions table

---

### Frontend (Ekram + Arafat)

**Day 1–3**
- [ ] Add tag filter chips to Home Feed
- [ ] Add sort dropdown (Newest, Highest Bounty, Most Voted)
- [ ] Build Search screen with search bar connected to `GET /api/questions/search`
- [ ] Show search results as question cards

**Day 4–5**
- [ ] Set up `firebase_messaging` in Flutter
- [ ] Request notification permission on first launch
- [ ] Register FCM token via `POST /api/notifications/fcm-token` after login
- [ ] Handle foreground and background push notification taps (navigate to relevant question)

**End of Week 7 Checklist:**
- [ ] Search and tag filtering working end-to-end
- [ ] Leaderboard endpoint returning correct rankings
- [ ] Badge awards triggering automatically
- [ ] Notifications inserted for all events
- [ ] FCM token registration working

---

## Week 8 — Better Features: Frontend

**Theme:** Build the UI for all Better-tier features. Backend is already done from Week 7.

**Goal by end of week:** All Better features visible and usable in the Flutter app.

---

### Backend (Saif + Rifat)

**Day 1–2**
- [ ] Performance check: run EXPLAIN ANALYZE on the 5 most common queries (feed, search, leaderboard, notifications, challenge)
- [ ] Add missing indexes if any queries are slow
- [ ] Fix any bugs found by the frontend team during Week 8

**Day 3–5**
- [ ] Write API documentation comments on all FastAPI endpoints (auto-generates Swagger UI at `/docs`)
- [ ] Review all RLS policies — make sure no data leaks between users
- [ ] Security review: check all endpoints validate ownership before mutating

---

### Frontend (Ekram + Arafat)

**Day 1–2 — Gamification UI**
- [ ] Build Leaderboard screen — weekly/all-time toggle, ranked list with avatars and points
- [ ] Add badge display to User Profile screen — grid of earned badges with icons
- [ ] Add streak display to User Profile screen — streak count with flame icon
- [ ] Add badge detail bottom sheet (tap a badge to see description and date earned)

**Day 3 — Notifications UI**
- [ ] Build Notifications screen — list of notifications sorted by newest
- [ ] Bell icon in app bar with unread count badge
- [ ] Mark as read on tap, mark all as read button
- [ ] Subscribe to Supabase Realtime for live bell count update

**Day 4 — Rich Rendering**
- [ ] Add `flutter_highlight` and `flutter_math_fork` to `pubspec.yaml`
- [ ] Replace plain text display in question body and answer body with a rich renderer:
  - Detect ` ``` ` blocks → `flutter_highlight`
  - Detect `$...$` and `$$...$$` → `flutter_math_fork`
- [ ] Test with a real LaTeX equation and a C++ code block

**Day 5 — AI Scanner UI**
- [ ] Add camera/gallery button to Post Question screen
- [ ] On image pick, call `POST /api/ai/scan`
- [ ] Show loading indicator while scanning
- [ ] Pre-fill the question body with extracted text
- [ ] Add duplicate warning dialog before question submit (calls `POST /api/ai/duplicate-check`)

**End of Week 8 Checklist:**
- [ ] Leaderboard, badges, and streaks visible in the app
- [ ] Notifications screen working with live unread count
- [ ] LaTeX and code highlighting rendering correctly
- [ ] AI scanner pre-filling question form
- [ ] Duplicate detection warning showing before submit

---

## Week 9 — Polish, Testing & Bug Fixes

**Theme:** No new features. The whole week is dedicated to making what exists reliable, fast, and presentable.

**Goal by end of week:** Zero known crashes. All flows work on both Android and iOS (or at least Android). App feels professional.

---

### Backend (Saif + Rifat)

**Day 1–2**
- [ ] Load test the most critical endpoints using Locust or k6:
  - `GET /api/questions` — 100 concurrent users
  - `POST /api/ai/hint` — check LLM timeout handling
- [ ] Add response caching for `GET /api/leaderboard` (cache 5 minutes — leaderboard doesn't need to be real-time)
- [ ] Add rate limiting on `POST /api/ai/hint` at the HTTP level (not just DB count)

**Day 3–4**
- [ ] Edge case testing:
  - Post question with 0 bounty
  - Accept own answer (should be blocked)
  - Vote on own content (decide: allow or block — pick one and enforce it)
  - Delete a question that has accepted answer (should be blocked)
  - Request hint with exactly 5 points (should work), then with 4 (should fail)
- [ ] Fix all edge cases found

**Day 5**
- [ ] Final security review:
  - All endpoints return `401` without a token
  - All ownership checks return `403` (not `404`) when user tries to edit someone else's content
  - No stack traces or internal errors exposed in API responses

---

### Frontend (Ekram + Arafat)

**Day 1–2**
- [ ] Fix all known UI bugs from previous weeks
- [ ] Test complete app flow on Android (physical device preferred)
- [ ] Test on a small screen (5 inch) and large screen (6.7 inch) — fix overflow issues

**Day 3**
- [ ] App icon and splash screen
- [ ] Consistent color theme across all screens — check for any unstyled widgets
- [ ] Typography review — heading sizes, body text, caption text consistent everywhere

**Day 4**
- [ ] Offline handling — show a "No internet connection" banner when offline
- [ ] Error handling — every API call should show a user-friendly error message, never a raw exception
- [ ] Session expiry handling — if token is expired, redirect to login automatically

**Day 5**
- [ ] Full regression test — go through every feature from the features.md Must and Better lists
- [ ] Record any remaining bugs → triage (fix now vs known issue)
- [ ] Tag the repo: `v1.1-beta`

**End of Week 9 Checklist:**
- [ ] No crashes on any Must or Better feature flow
- [ ] App icon and splash screen done
- [ ] All error states handled gracefully
- [ ] Repo tagged `v1.1-beta`

---

## Week 10 — Final Submission & Demo Prep

**Theme:** Documentation, deployment, and presentation. No new features or risky changes.

**Goal by end of week:** A deployed, working app with a polished report and a confident demo.

---

### Backend (Saif + Rifat)

**Day 1**
- [ ] Final production deployment on Railway or Render
- [ ] Set all environment variables properly (not hardcoded)
- [ ] Enable HTTPS — confirm all endpoints are served over `https://`
- [ ] Test the production URL from the Flutter app — not just localhost

**Day 2**
- [ ] Swagger UI is accessible at `/docs` — review all endpoint descriptions are readable
- [ ] Seed the production DB with demo data:
  - 3–4 sample users
  - 5–6 sample questions across different tags
  - Several answers and votes
  - At least one daily challenge
- [ ] Make sure the `on_auth_user_created` trigger is working on the production Supabase project

**Day 3–4**
- [ ] Update the project report (the corrected PDF from earlier):
  - Final ER diagram matching the actual schema
  - Final API list matching `api.md`
  - Finalized features list matching `features.md`
  - Any changes made during development
- [ ] Compile final report PDF

**Day 5**
- [ ] Demo preparation:
  - Script a 10-minute walkthrough covering: Register → Post question with bounty → Another user answers → Accept answer → Points transfer → Daily challenge → AI hint → Leaderboard
  - Practice the demo twice as a team
  - Have a backup video recording of the demo in case of live technical issues
- [ ] Submit

---

### Frontend (Ekram + Arafat)

**Day 1–2**
- [ ] Build a release APK: `flutter build apk --release`
- [ ] Test the release APK on a real device (release mode behaves differently from debug)
- [ ] Fix any issues found in release mode

**Day 3–4**
- [ ] Record a 3–5 minute screen recording of the app demo (backup for submission)
- [ ] Make sure the app connects to the production backend URL, not localhost
- [ ] Final UI review — screenshots for the report

**Day 5**
- [ ] Submit APK + source code
- [ ] Tag the repo: `v1.0-release`
- [ ] Team retrospective — what went well, what to improve next time

**End of Week 10 Checklist:**
- [ ] App deployed and connecting to production backend
- [ ] Release APK built and tested
- [ ] Final report submitted
- [ ] Demo practiced and recorded
- [ ] Repo tagged `v1.0-release`

---

## Full Week-by-Week Summary

| Week | Backend | Frontend |
|---|---|---|
| 1 | DB setup, FastAPI init, JWT verification | Flutter init, Supabase auth, login/register screens |
| 2 | Questions & answers CRUD, bounty transfer | API client setup, mock UI screens |
| 3 | User profile, storage buckets, error handling | Connect feed, Q&A, profile to real API |
| 4 | Voting endpoints, points ledger validation | Vote buttons, points balance, transaction history |
| 5 | AI hint endpoint, daily challenge + cron | AI hint UI, daily challenge screen |
| 6 | Integration tests, edge case fixes | Empty states, loading states, full MVP test |
| 7 | Search, leaderboard, badges, notifications, FCM, AI scanner | Tag filters, search screen, FCM setup |
| 8 | Performance, security review, Swagger docs | Leaderboard, notifications, rich rendering, AI scanner UI |
| 9 | Load testing, edge cases, security review | Bug fixes, UI polish, offline handling, regression test |
| 10 | Production deploy, seed data, report | Release APK, demo prep, submission |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Codeforces API changes or goes down | Low | Medium | Cache the last successful problem. Have 2–3 fallback hardcoded problems. |
| LLM API rate limit or cost overrun | Medium | High | Set a monthly spend cap. Cache identical hint requests. Rate-limit aggressively (3 per hour). |
| Supabase free tier limits hit | Low | High | Monitor usage weekly. Free tier allows 500MB DB and 1GB storage — sufficient for a project. |
| Team member falls behind | Medium | High | Weekly check-in. If one area is behind, both backend or both frontend members shift focus together. |
| Circular FK migration issue | Low | Medium | The `schema.sql` already handles this correctly with `DEFERRABLE`. Run on a test project first. |
| Flutter release build behaves differently | Medium | Medium | Build release APK in Week 9, not Week 10. Never test only in debug mode. |
| Demo fails live | Low | High | Always have a screen recording as backup. Seed demo data in advance. |

---

## Definition of Done

A feature is **done** when:
1. The backend endpoint returns correct data for valid input
2. The backend returns correct error codes for invalid input
3. The Flutter screen renders the data correctly
4. The Flutter screen handles loading, error, and empty states
5. The feature is tested end-to-end on a real device
6. The PR is reviewed and merged to `main`