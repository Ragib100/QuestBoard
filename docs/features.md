# QuestBoard Feature Reference

**Project:** QuestBoard — A Gamified Q&A Platform for STEM Problem Solving  
**Stack:** Flutter · FastAPI · Supabase PostgreSQL · Supabase Auth · Supabase Storage · Firebase

> Features are divided into three tiers based on implementation complexity relative to the team's current skill level (REST APIs, basic CRUD, simple chatbot experience).
>
> **Build order recommendation:** Complete all Must features first before touching Better or Next Level. A working MVP is more valuable than a half-finished feature-rich app.

---

## Table of Contents

1. [Must Implement](#1-must-implement)
   - [Authentication & Profiles](#11-authentication--profiles)
   - [Q&A with Bounty System](#12-qa-with-bounty-system)
   - [Voting System](#13-voting-system)
   - [AI Hint Mentor](#14-ai-hint-mentor)
   - [Daily Coding Challenge](#15-daily-coding-challenge)
2. [Better to Implement](#2-better-to-implement)
   - [Rich Content Rendering](#21-rich-content-rendering)
   - [Gamification Layer](#22-gamification-layer)
   - [Smart Filtering & Search](#23-smart-filtering--search)
   - [In-App Notifications](#24-in-app-notifications)
   - [Push Notifications](#25-push-notifications)
   - [AI Problem Scanner](#26-ai-problem-scanner)
   - [Duplicate Question Detection](#27-duplicate-question-detection)
3. [Next Level Features](#3-next-level-features)
   - [Live Discussion Rooms](#31-live-discussion-rooms)
   - [In-App Code Runner](#32-in-app-code-runner)
   - [Personalized Study Path](#33-personalized-study-path)
   - [Auto Difficulty Grader](#34-auto-difficulty-grader)
   - [Follow System & Personalized Feed](#35-follow-system--personalized-feed)
   - [Admin Dashboard](#36-admin-dashboard)

---

## 1. Must Implement

These are the core features that define QuestBoard. Without these, the app does not exist. All of these map directly to skills the team already has — JWT auth, CRUD operations, and basic API calls.

---

### 1.1 Authentication & Profiles

**What it is:**
Secure user registration, login, logout, password reset, and public profile pages showing stats and earned points.

**Why it's must:**
Every other feature depends on knowing who the user is. Without auth there is no bounty economy, no voting ownership, no hint tracking.

**How it works:**
- Supabase Auth handles registration, login, logout, email verification, forgot password (reset link), and change password entirely on the Flutter client using the `supabase_flutter` SDK.
- On first signup, a database trigger (`on_auth_user_created`) automatically creates a row in the `users` table and credits 100 starting points.
- FastAPI reads the Supabase JWT (`sub` claim) on every protected endpoint to identify the user.
- Profile data (username, avatar, bio, points, streak) is served from the `users` table via `GET /api/users/{id}`.
- Avatar images are stored in the `avatars` Supabase Storage bucket.

**Endpoints involved:**
- All auth handled by Supabase SDK (no custom endpoints)
- `GET /api/users/{id}`
- `PATCH /api/users/{id}`
- `GET /api/users/{id}/points`
- `GET /api/users/{id}/streak`

**DB tables involved:**
`users`, `point_transactions`

**Effort:** Low — team has done JWT auth before. Supabase reduces it further.

---

### 1.2 Q&A with Bounty System

**What it is:**
Users post STEM questions with an optional point bounty attached. Other users answer. The question owner accepts the best answer, which transfers the bounty points to the helper automatically.

**Why it's must:**
This is the entire value proposition of QuestBoard. It is what separates it from a regular forum — real incentive to help.

**How it works:**
- User posts a question with `bounty_points`. This amount is immediately deducted from their `users.points` balance and recorded in `point_transactions` with `reason = 'bounty_posted'`.
- Other users submit answers via `POST /api/questions/{id}/answers`.
- The question owner calls `POST /api/answers/{id}/accept`. This:
  1. Sets `answers.is_accepted = true`
  2. Sets `questions.is_solved = true` and `questions.accepted_answer_id`
  3. Adds `bounty_points` to the helper's `users.points`
  4. Logs a `point_transactions` row with `reason = 'bounty_awarded'`
  5. Creates a `notifications` row for the helper
- All of steps 1–5 happen inside a single DB transaction to prevent partial updates.

**Endpoints involved:**
- `GET /api/questions`
- `POST /api/questions`
- `GET /api/questions/{id}`
- `PATCH /api/questions/{id}`
- `DELETE /api/questions/{id}`
- `GET /api/questions/{id}/answers`
- `POST /api/questions/{id}/answers`
- `PATCH /api/answers/{id}`
- `DELETE /api/answers/{id}`
- `POST /api/answers/{id}/accept`

**DB tables involved:**
`questions`, `answers`, `question_tags`, `point_transactions`, `notifications`

**Effort:** Medium — straightforward CRUD with a transaction on accept. Team has done this pattern before.

---

### 1.3 Voting System

**What it is:**
Users upvote or downvote questions and answers. Votes affect content ranking and small point adjustments for the content author.

**Why it's must:**
Without votes, there is no way to surface quality content. The feed would be pure chronological with no signal. Votes are also how the community self-moderates.

**How it works:**
- A single `votes` table handles both question and answer votes using `target_type` (`question` or `answer`) and `target_id`.
- Calling vote with the same value again **removes** the vote (toggle). Calling with the opposite value **updates** it.
- Upvoting someone's content gives them `+1` point (`reason = 'vote_received'`). Downvoting costs them `-1` point (`reason = 'vote_lost'`).
- The unique DB constraint on `(user_id, target_type, target_id)` prevents double-voting at the database level — no application logic needed for this guard.

**Endpoints involved:**
- `POST /api/questions/{id}/vote`
- `POST /api/answers/{id}/vote`

**DB tables involved:**
`votes`, `point_transactions`, `users`

**Effort:** Low — two endpoints with simple upsert logic.

---

### 1.4 AI Hint Mentor

**What it is:**
Users can spend 5 points to request an AI-generated Socratic hint on any question. The AI guides them toward the answer without revealing it directly.

**Why it's must:**
This is QuestBoard's core differentiator from Stack Overflow. It promotes actual learning instead of answer copying.

**How it works:**
- User calls `POST /api/ai/hint` with `question_id` and optional `user_context`.
- FastAPI checks the user has ≥ 5 points. If not, returns `402`.
- Points are deducted and logged **before** calling the LLM. If the LLM call fails, points are refunded in the same transaction.
- The system prompt sent to the LLM is strictly Socratic:
  ```
  You are a STEM tutor. The student is stuck on a problem.
  Ask them a leading question or give a small nudge that helps
  them think in the right direction. Never reveal the answer
  directly. Keep your response under 100 words.
  ```
- The hint text and cost are saved to `ai_hints` for audit and rate-limiting.
- Rate limit: max 3 hints per user per question per hour (checked via a count query on `ai_hints`).

**Endpoints involved:**
- `POST /api/ai/hint`

**DB tables involved:**
`ai_hints`, `point_transactions`, `users`

**Effort:** Low — one API call with a well-crafted system prompt. Team has built a chatbot before.

---

### 1.5 Daily Coding Challenge

**What it is:**
Every day at midnight, a cron job fetches a problem from the Codeforces public API and saves it as the daily challenge. Users who solve it earn bonus points. Fast solvers are ranked on a per-challenge leaderboard.

**Why it's must:**
The daily challenge drives daily active users and streak engagement. It gives competitive coders a reason to return every day even without a bounty question to answer.

**How it works:**
- A scheduled task (cron job or Supabase pg_cron) runs at midnight and calls the Codeforces API to pick a problem based on difficulty.
- The problem is saved to `daily_challenges` with `challenge_date = today` (unique — prevents duplicates).
- Users call `POST /api/challenges/{id}/attempt` to register they started. This inserts a `challenge_attempts` row with `is_solved = false`.
- When a user solves it, `POST /api/challenges/{id}/solve` flips `is_solved = true`, sets `solved_at = now()`, and awards `bonus_points` via `point_transactions`.
- `streak_days` on the `users` table is incremented if this is their first activity today.

**Endpoints involved:**
- `GET /api/challenges/today`
- `GET /api/challenges`
- `POST /api/challenges/{id}/attempt`
- `POST /api/challenges/{id}/solve`

**DB tables involved:**
`daily_challenges`, `challenge_attempts`, `point_transactions`, `users`

**Effort:** Medium — involves a third-party API call and a scheduled task, both new but well-documented.

---

## 2. Better to Implement

These features significantly improve the user experience and are achievable by learning one new thing each. None require a major architecture change — they extend what the Must features already built.

---

### 2.1 Rich Content Rendering

**What it is:**
Code blocks in questions and answers are syntax-highlighted. Math equations written in LaTeX (e.g. `$x^2 + y^2 = z^2$`) are rendered beautifully inline.

**Why it's better:**
QuestBoard targets STEM students. Without math rendering, users cannot properly express equations. Without code highlighting, code answers are unreadable walls of text.

**How it works:**
- **Code highlighting:** Use the `flutter_highlight` package on the Flutter side. No backend changes needed — the body text already stores code blocks in markdown triple-backtick format.
- **Math rendering:** Use the `flutter_math_fork` package for inline and display LaTeX. Questions and answers are scanned for `$...$` (inline) and `$$...$$` (display) and rendered by the widget.
- Both are purely frontend — the backend stores plain text and the Flutter app renders it.

**Flutter packages:**
```yaml
flutter_highlight: ^0.7.0
flutter_math_fork: ^0.7.2
```

**Effort:** Low — add two Flutter packages and swap the text display widget.

---

### 2.2 Gamification Layer

**What it is:**
Weekly leaderboard ranking users by points, activity streaks tracked per day, and achievement badges awarded automatically when milestones are reached.

**Why it's better:**
Gamification is what makes users come back. Streaks create daily habits. Leaderboards create healthy competition. Badges give a sense of progression.

**How it works:**

**Leaderboard:**
- `GET /api/leaderboard?period=weekly` runs `SELECT * FROM users ORDER BY points DESC LIMIT 20`.
- Weekly reset: a cron job snapshots scores every Monday and resets the weekly counter. All-time leaderboard never resets.

**Streaks:**
- On each login or activity, FastAPI checks `users.last_active`. If it was yesterday, increment `streak_days`. If it was today already, do nothing. If it was older than yesterday, reset to 1.
- A `daily_bonus` of 10 points is awarded on the first activity of each day.

**Badges:**
- Badge checks run as a background task after any significant event (answer accepted, challenge solved, streak updated).
- Each badge has a simple rule checked via a DB query:

| Badge | Check |
|---|---|
| `first_answer` | `COUNT(answers WHERE author_id = user) >= 1` |
| `first_bounty` | `COUNT(point_transactions WHERE reason = 'bounty_awarded' AND user_id = user) >= 1` |
| `streak_5` | `users.streak_days >= 5` |
| `streak_30` | `users.streak_days >= 30` |
| `bounty_hunter` | `COUNT(point_transactions WHERE reason = 'bounty_awarded' AND user_id = user) >= 10` |
| `challenger` | `COUNT(challenge_attempts WHERE user_id = user AND is_solved = true) >= 7` |

**Endpoints involved:**
- `GET /api/leaderboard`
- `GET /api/users/{id}/badges`
- `GET /api/users/{id}/streak`
- `GET /api/badges`

**DB tables involved:**
`users`, `badges`, `user_badges`, `point_transactions`, `challenge_attempts`

**Effort:** Medium — leaderboard is one query; streaks are date math; badges are background tasks with simple count queries.

---

### 2.3 Smart Filtering & Search

**What it is:**
Users can filter the question feed by tag (e.g. DSA, Math, Physics), sort by newest/bounty/votes, and full-text search across question titles and bodies.

**Why it's better:**
Without filtering, the feed becomes unusable as content grows. A math student shouldn't see every DSA question. Search lets users find existing answers before posting duplicates.

**How it works:**
- Tag filtering: `GET /api/questions?tag=dsa` joins `question_tags` and filters by tag name.
- Sorting: `?sort=bounty` orders by `bounty_points DESC`, `?sort=votes` orders by a vote count subquery.
- Full-text search: `GET /api/questions/search?q=bitmask` uses PostgreSQL `pg_trgm` similarity search on `title` and `body`. The `gin_trgm_ops` indexes (already in the schema setup SQL) make this fast.

**Endpoints involved:**
- `GET /api/questions` (extended with query params)
- `GET /api/questions/search`
- `GET /api/tags`

**DB tables involved:**
`questions`, `question_tags`, `tags`, `votes`

**Effort:** Low — query parameter extensions and one `pg_trgm` query. Extension is already enabled in the setup SQL.

---

### 2.4 In-App Notifications

**What it is:**
A bell icon in the Flutter app showing unread notifications. Events like "your question was answered", "your answer was accepted", and "you earned a badge" create notification rows automatically.

**Why it's better:**
Without notifications, users have no reason to reopen the app. They won't know someone answered their question unless they manually check.

**How it works:**
- The `notifications` table stores one row per event per user.
- Notification rows are inserted by FastAPI after each triggering event (answer posted, answer accepted, badge awarded, vote received).
- Flutter polls `GET /api/notifications` on app focus, or uses Supabase Realtime to listen for new rows (a simple `supabase.from('notifications').stream()` subscription).
- The bell icon shows the count from `notifications WHERE user_id = me AND is_read = false`.
- `PATCH /api/notifications/read-all` marks all as read when the user opens the notification panel.

**Endpoints involved:**
- `GET /api/notifications`
- `PATCH /api/notifications/{id}/read`
- `PATCH /api/notifications/read-all`

**DB tables involved:**
`notifications`

**Effort:** Low — simple insert/read CRUD. Supabase Realtime makes the live bell update trivial.

---

### 2.5 Push Notifications

**What it is:**
Device-level push notifications via Firebase Cloud Messaging (FCM) that alert users even when the app is closed.

**Why it's better:**
In-app notifications only work when the app is open. Push notifications bring users back to the app — essential for bounty questions that need a quick answer.

**How it works:**
- On login, Flutter calls `POST /api/notifications/fcm-token` to register the device token with the backend.
- When a notification event fires on the backend (e.g. answer accepted), FastAPI sends a push via the Firebase Admin SDK alongside the in-app notification row insert.
- FCM handles delivery to iOS and Android.
- Firebase is already in the project stack — this is a straightforward addition once in-app notifications (2.4) are working.

**Endpoints involved:**
- `POST /api/notifications/fcm-token`

**DB tables involved:**
`users` (token stored here or in a separate `fcm_tokens` table)

**Flutter packages:**
```yaml
firebase_messaging: ^14.0.0
```

**Effort:** Medium — Firebase Admin SDK setup on the backend, `firebase_messaging` on Flutter. Well-documented.

---

### 2.6 AI Problem Scanner

**What it is:**
Users photograph a handwritten or printed STEM problem. The AI extracts the text automatically and pre-fills the question form.

**Why it's better:**
Students frequently have textbook or assignment problems they want to ask about. Typing math notation is painful. A photo → text flow removes the biggest friction point for posting.

**How it works:**
- User picks or photographs an image in Flutter and uploads it to `POST /api/ai/scan` as `multipart/form-data`.
- FastAPI sends the image to a Vision-capable LLM (GPT-4o or Google Gemini) with the prompt: `"Extract the problem text from this image exactly as written."`.
- The extracted text is returned to Flutter and pre-filled in the question body field.
- The image itself can optionally be saved to the `question-images` Supabase Storage bucket and attached to the question.

**Endpoints involved:**
- `POST /api/ai/scan`

**DB tables involved:**
`questions` (image_url field)

**Effort:** Medium — one multipart upload endpoint and one Vision API call. No new tables needed.

---

### 2.7 Duplicate Question Detection

**What it is:**
Before a user submits a question, the backend checks if a very similar question already exists and warns the user with links to the existing ones.

**Why it's better:**
Prevents the feed from filling up with repeated versions of the same homework question. Also helps askers find answers that already exist without needing to search manually.

**How it works:**
- User calls `POST /api/ai/duplicate-check` with the draft `title` and `body`.
- FastAPI uses PostgreSQL `pg_trgm` similarity (`similarity(title, $1) > 0.7`) to find existing questions with similar titles — fast because of the gin index.
- Optionally, the draft can also be sent to the LLM for a semantic similarity check for higher accuracy.
- Returns a list of potentially duplicate questions with similarity scores.
- The Flutter UI shows these as suggestions: "Did you mean one of these?" before allowing submission.

**Endpoints involved:**
- `POST /api/ai/duplicate-check`

**DB tables involved:**
`questions`

**Effort:** Low — one query using `pg_trgm` which is already enabled. Optional LLM call for better accuracy.

---

## 3. Next Level Features

These features each introduce a fundamentally new technical concept. Build these only after the Must and Better tiers are complete and stable. Each one is a meaningful learning milestone on its own.

---

### 3.1 Live Discussion Rooms

**What it is:**
Real-time chat room attached to each question. Users can collaborate live while solving, see who is online, and exchange messages without posting formal answers.

**Why it's next level:**
WebSockets are stateful and require a different mental model from REST. Connection lifecycle, reconnection logic, and message ordering all need careful handling.

**How it works:**
- FastAPI exposes a WebSocket endpoint: `ws://api.questboard.app/ws/rooms/{question_id}`.
- Each connected client is tracked in memory (or Redis for multi-instance). Messages are broadcast to all clients in the same room.
- Presence (who is online) is stored temporarily in Firebase Realtime Database — this is the one case where Firebase makes more sense than Postgres because presence data is ephemeral and needs millisecond-level sync.
- Message history (last 50 messages) is stored in a `room_messages` table in Postgres.
- Flutter uses the `web_socket_channel` package to connect.

**New concepts learned:**
WebSocket lifecycle management, broadcast patterns, ephemeral vs persistent state.

**Flutter packages:**
```yaml
web_socket_channel: ^2.4.0
```

**Effort:** High — new paradigm. Start with a simple echo server before integrating into QuestBoard.

---

### 3.2 In-App Code Runner

**What it is:**
Users can run code snippets directly inside the app and see the output inline, without leaving QuestBoard.

**Why it's next level:**
Sandboxed code execution is a security-sensitive feature. Running untrusted code requires careful isolation — you delegate this to a third-party API (Judge0 or Piston) rather than running it yourself.

**How it works:**
- User writes code in the answer/question editor and taps "Run".
- Flutter sends the code and language to `POST /api/code/run`.
- FastAPI forwards it to the [Judge0 API](https://judge0.com) or [Piston API](https://github.com/engineer-man/piston) (both free tiers available).
- The execution result (stdout, stderr, time, memory) is returned to Flutter and displayed below the code block.
- No server-side code execution on your own infrastructure — you are just proxying to a safe sandbox.

**Endpoints involved:**
- `POST /api/code/run`

**Supported languages (via Judge0):**
C++, Python, Java, JavaScript, and 40+ more.

**Effort:** High conceptually (understanding sandboxing) but Medium in practice (it is just an API call with a proxy endpoint).

---

### 3.3 Personalized Study Path

**What it is:**
Based on a user's question history, solve rate, and hint usage patterns, the AI recommends specific topics to study and questions to attempt next.

**Why it's next level:**
Requires enough historical data to be meaningful, and a more complex AI prompt that synthesizes multiple data points into a recommendation. Also requires the Must and Better features to be fully running first — you need data to analyze.

**How it works:**
- `GET /api/ai/study-path/{user_id}` queries the user's:
  - Tags of questions they asked (weak areas)
  - Tags of questions they answered correctly (strong areas)
  - Challenges they failed vs solved
  - Hints they requested (which topics needed AI help)
- This summary is sent to the LLM: `"Based on this student's activity, recommend 3 topics to focus on and suggest one question from each."`.
- The response is returned as a structured JSON recommendation.

**Endpoints involved:**
- `GET /api/ai/study-path/{user_id}`

**DB tables involved:**
`questions`, `answers`, `challenge_attempts`, `ai_hints`, `question_tags`, `tags`

**Effort:** High — depends on all previous features being built. The AI prompt engineering is non-trivial to get useful recommendations.

---

### 3.4 Auto Difficulty Grader

**What it is:**
When a question is posted, the AI automatically estimates its difficulty (Easy / Medium / Hard) and tags it. This helps users filter by skill level.

**Why it's next level:**
Difficulty is subjective and context-dependent. Getting the AI to grade consistently across very different STEM domains (a calculus integral vs a graph algorithm) requires careful prompt design and possibly few-shot examples.

**How it works:**
- After a question is created, FastAPI fires a background task (using FastAPI's `BackgroundTasks`) that sends the question title and body to the LLM.
- The prompt instructs the LLM to return only one of: `easy`, `medium`, or `hard` with a one-line justification.
- The result updates `questions.difficulty`.
- Flutter shows a difficulty badge on each question card.

**Endpoints involved:**
- `POST /api/ai/grade-difficulty` (or triggered automatically on question post)

**DB tables involved:**
`questions`

**Effort:** Medium-High — the background task pattern in FastAPI is new. Prompt consistency across domains requires iteration.

---

### 3.5 Follow System & Personalized Feed

**What it is:**
Users can follow other users. The home feed shows questions from followed users first, alongside a global feed tab.

**Why it's next level:**
A social graph requires a new table, new feed query logic (joining followers), and UI changes to the home screen. It also raises questions about feed ranking that get complex quickly.

**How it works:**
- A `user_follows` table stores `(follower_id, following_id)` pairs.
- `POST /api/users/{id}/follow` and `DELETE /api/users/{id}/follow` manage the relationship.
- `GET /api/questions/feed` returns questions from followed users, sorted by recency. Falls back to global feed if the user follows no one.
- The Flutter home screen gets a "Following" tab alongside the global "All" tab.

**New DB table:**
```sql
CREATE TABLE public.user_follows (
  follower_id  uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  following_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at   timestamp NOT NULL DEFAULT now(),
  PRIMARY KEY (follower_id, following_id)
);
```

**Endpoints involved:**
- `POST /api/users/{id}/follow`
- `DELETE /api/users/{id}/follow`
- `GET /api/questions/feed`

**Effort:** High — the feed ranking query across a social graph is non-trivial at scale. Start with a simple recency sort before adding ranking signals.

---

### 3.6 Admin Dashboard

**What it is:**
A separate dashboard (web or Flutter) for the QuestBoard team showing platform-wide analytics: question volume, active users, top helpers, point economy health, and daily challenge solve rates.

**Why it's next level:**
Not user-facing, so low priority. But very useful once the app has real users. Requires aggregation queries and chart rendering.

**How it works:**
- A set of admin-only FastAPI endpoints (protected by a role check: `users.is_admin = true`) return aggregated stats.
- Charts rendered using `fl_chart` in Flutter or a simple web dashboard using Chart.js.
- Key metrics:

| Metric | Query |
|---|---|
| Daily active users | `COUNT DISTINCT user_id FROM point_transactions WHERE DATE(created_at) = today` |
| Questions posted today | `COUNT FROM questions WHERE DATE(created_at) = today` |
| Top helpers this week | `GROUP BY user_id FROM point_transactions WHERE reason = 'bounty_awarded'` |
| Point economy total | `SUM(amount) FROM point_transactions` (should always be net positive) |
| Challenge solve rate | `COUNT(is_solved=true) / COUNT(*) FROM challenge_attempts WHERE challenge_date = today` |

**Endpoints involved:**
- `GET /api/admin/stats`
- `GET /api/admin/users`
- `GET /api/admin/economy`

**Effort:** High — low user value but high team learning value. Build last.

---

## Summary Table

| Feature | Tier | Effort | New Concept |
|---|---|---|---|
| Auth & Profiles | Must | Low | Supabase Auth SDK |
| Q&A with Bounty | Must | Medium | DB transactions |
| Voting System | Must | Low | Polymorphic table |
| AI Hint Mentor | Must | Low | LLM system prompt |
| Daily Challenge | Must | Medium | Cron + third-party API |
| Rich Rendering | Better | Low | Flutter packages |
| Gamification | Better | Medium | Background tasks, date math |
| Smart Filtering | Better | Low | pg_trgm queries |
| In-App Notifications | Better | Low | Supabase Realtime |
| Push Notifications | Better | Medium | Firebase Admin SDK |
| AI Problem Scanner | Better | Medium | Vision API + multipart upload |
| Duplicate Detection | Better | Low | pg_trgm similarity |
| Live Discussion Rooms | Next | High | WebSockets |
| In-App Code Runner | Next | Medium | Sandboxed execution API |
| Personalized Study Path | Next | High | Multi-signal AI prompt |
| Auto Difficulty Grader | Next | Medium | Background AI task |
| Follow System & Feed | Next | High | Social graph queries |
| Admin Dashboard | Next | High | Aggregation queries, charts |