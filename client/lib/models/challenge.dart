import '../core/app_time.dart';
import 'code_submission.dart';
import 'quest.dart' show UserSummary;

/// One Codeforces problem, chosen for a calendar day.
class DailyChallenge {
  const DailyChallenge({
    required this.id,
    required this.codeforcesId,
    required this.title,
    required this.body,
    required this.cfRating,
    required this.difficulty,
    required this.sourceUrl,
    this.submitUrl,
    required this.bonusPoints,
    required this.challengeDate,
    this.awardPoints = 0,
    this.ageDays = 0,
  });

  final String id;
  final String? codeforcesId;
  final String title;
  final String body;
  final int? cfRating;
  final String? difficulty;
  final String? sourceUrl;

  /// Codeforces' own submit form for this problem. The app hosts this page in
  /// a WebView rather than posting anywhere itself — Codeforces has no submit
  /// API (decisions.md D43).
  final String? submitUrl;

  /// The challenge's value on its own day. Do not show this as what solving
  /// pays — [awardPoints] is that, and for an archived challenge they differ.
  final int bonusPoints;
  final DateTime challengeDate;

  /// What solving it is worth *right now*, after the age decay. Computed by
  /// the server per request, because the answer changes at midnight UTC.
  final int awardPoints;

  /// How many days old the challenge is. 0 is today's.
  final int ageDays;

  /// True once the decay has bottomed out — solving it will not get cheaper.
  bool get isAtFloor => ageDays > 0 && awardPoints <= (bonusPoints * 0.2).round();

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
        id: json['id'] as String,
        codeforcesId: json['codeforces_id'] as String?,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        cfRating: json['cf_rating'] as int?,
        difficulty: json['difficulty'] as String?,
        sourceUrl: json['source_url'] as String?,
        submitUrl: json['submit_url'] as String?,
        bonusPoints: json['bonus_points'] as int? ?? 0,
        challengeDate:
            parseServerDate(json['challenge_date'] as String? ?? '') ??
                dhakaToday(),
        // Falls back to the base so an older server, or a cached response,
        // never renders a challenge as worth nothing.
        awardPoints:
            json['award_points'] as int? ?? json['bonus_points'] as int? ?? 0,
        ageDays: json['age_days'] as int? ?? 0,
      );
}

class ChallengeAttempt {
  const ChallengeAttempt({
    required this.isSolved,
    required this.solvedAt,
    this.awardedPoints = 0,
    this.submission = CodeSubmission.empty,
  });

  final bool isSolved;
  final DateTime? solvedAt;

  /// What this solve actually paid. Lower than the challenge's `bonusPoints`
  /// when it was claimed late, which is why the screen shows this number back
  /// rather than recomputing one.
  final int awardedPoints;

  /// The solution submitted through the app, if any. Kept even on an unsolved
  /// attempt, so claiming too early does not throw away what was typed.
  final CodeSubmission submission;

  factory ChallengeAttempt.fromJson(Map<String, dynamic> json) =>
      ChallengeAttempt(
        isSolved: json['is_solved'] as bool? ?? false,
        solvedAt: parseServerTime(json['solved_at'] as String? ?? ''),
        awardedPoints: json['awarded_points'] as int? ?? 0,
        submission: CodeSubmission.fromJson(json),
      );
}

/// `GET /api/challenges/today`, `/challenges/{id}` and every row of
/// `/challenges` — the challenge plus everything the screen needs to say what
/// the viewer can actually do with it. One shape for today's and for an
/// archived one, which is what lets a single screen render both.
class TodayChallenge {
  const TodayChallenge({
    required this.challenge,
    required this.isToday,
    required this.solverCount,
    required this.myAttempt,
    required this.codeforcesVerified,
  });

  final DailyChallenge challenge;

  /// False when Codeforces was unreachable and the server fell back to the
  /// last challenge it stored. The screen says so rather than mislabelling it.
  final bool isToday;
  final int solverCount;
  final ChallengeAttempt? myAttempt;
  final bool codeforcesVerified;

  bool get isSolved => myAttempt?.isSolved ?? false;

  /// The same view with a freshly written attempt patched in.
  ///
  /// Saving code returns the updated attempt, so the screen can show it
  /// without re-reading the whole challenge — and a re-read is not harmless
  /// here: it rebuilds the code editor from the server while the user is still
  /// typing in it.
  TodayChallenge withAttempt(ChallengeAttempt attempt) => TodayChallenge(
        challenge: challenge,
        isToday: isToday,
        solverCount: solverCount,
        myAttempt: attempt,
        codeforcesVerified: codeforcesVerified,
      );

  factory TodayChallenge.fromJson(Map<String, dynamic> json) => TodayChallenge(
        challenge: DailyChallenge.fromJson(
            json['challenge'] as Map<String, dynamic>),
        isToday: json['is_today'] as bool? ?? true,
        solverCount: json['solver_count'] as int? ?? 0,
        myAttempt: json['my_attempt'] == null
            ? null
            : ChallengeAttempt.fromJson(
                json['my_attempt'] as Map<String, dynamic>),
        codeforcesVerified: json['codeforces_verified'] as bool? ?? false,
      );
}

class ChallengeSolver {
  const ChallengeSolver({
    required this.rank,
    required this.solvedAt,
    required this.user,
    this.awardedPoints = 0,
  });

  final int rank;
  final DateTime? solvedAt;
  final UserSummary user;

  /// What this solver was paid — a same-day solve and a late one on the same
  /// challenge are worth different amounts, and the list says so.
  final int awardedPoints;

  factory ChallengeSolver.fromJson(Map<String, dynamic> json) => ChallengeSolver(
        rank: json['rank'] as int? ?? 0,
        solvedAt: parseServerTime(json['solved_at'] as String? ?? ''),
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
        awardedPoints: json['awarded_points'] as int? ?? 0,
      );
}

/// One worked example from a problem statement.
class StatementSample {
  const StatementSample({required this.input, required this.output});

  final String input;
  final String output;

  factory StatementSample.fromJson(Map<String, dynamic> json) => StatementSample(
        input: json['input'] as String? ?? '',
        output: json['output'] as String? ?? '',
      );
}

/// `GET /api/challenges/{id}/statement` — the real Codeforces problem text.
///
/// [available] is false whenever Codeforces would not serve the page. That is a
/// routine outcome rather than an error: their API has no statement method, so
/// the only source is the problem page and it sits behind Cloudflare. The
/// screen falls back to the challenge's own summary and says so (D45).
class ProblemStatement {
  const ProblemStatement({
    required this.available,
    this.html = '',
    this.timeLimit = '',
    this.memoryLimit = '',
    this.samples = const [],
    this.sourceUrl,
    this.submitUrl,
  });

  final bool available;

  /// Sanitised HTML — scripts, frames and event handlers already removed
  /// server-side, because this is rendered in a WebView with a channel open
  /// back into the app.
  final String html;
  final String timeLimit;
  final String memoryLimit;
  final List<StatementSample> samples;
  final String? sourceUrl;
  final String? submitUrl;

  factory ProblemStatement.fromJson(Map<String, dynamic> json) =>
      ProblemStatement(
        available: json['available'] as bool? ?? false,
        html: json['html'] as String? ?? '',
        timeLimit: json['time_limit'] as String? ?? '',
        memoryLimit: json['memory_limit'] as String? ?? '',
        samples: [
          for (final row in (json['samples'] as List? ?? const []))
            StatementSample.fromJson(row as Map<String, dynamic>),
        ],
        sourceUrl: json['source_url'] as String?,
        submitUrl: json['submit_url'] as String?,
      );
}

/// What the server wants submitted to prove a Codeforces handle is yours.
class CodeforcesVerification {
  const CodeforcesVerification({
    required this.handle,
    required this.codeforcesId,
    required this.problemUrl,
    required this.submitUrl,
    required this.windowMinutes,
  });

  final String handle;
  final String codeforcesId;
  final String problemUrl;

  /// Where the deliberate compilation error is actually submitted.
  final String submitUrl;
  final int windowMinutes;

  factory CodeforcesVerification.fromJson(Map<String, dynamic> json) =>
      CodeforcesVerification(
        handle: json['handle'] as String? ?? '',
        codeforcesId: json['codeforces_id'] as String? ?? '',
        problemUrl: json['problem_url'] as String? ?? '',
        // Falls back to the statement page, which also carries a submit box —
        // an older server that does not send this is degraded, not broken.
        submitUrl: json['submit_url'] as String? ??
            json['problem_url'] as String? ??
            '',
        windowMinutes: json['window_minutes'] as int? ?? 30,
      );
}


/// One page of the archive — `GET /api/challenges`.
class ChallengePage {
  const ChallengePage({
    required this.items,
    required this.page,
    required this.total,
    required this.hasMore,
  });

  final List<TodayChallenge> items;
  final int page;
  final int total;
  final bool hasMore;

  factory ChallengePage.fromJson(Map<String, dynamic> json) => ChallengePage(
        items: [
          for (final row in (json['items'] as List? ?? const []))
            TodayChallenge.fromJson(row as Map<String, dynamic>),
        ],
        page: json['page'] as int? ?? 1,
        total: json['total'] as int? ?? 0,
        hasMore: json['has_more'] as bool? ?? false,
      );
}
