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
    required this.bonusPoints,
    required this.challengeDate,
  });

  final String id;
  final String? codeforcesId;
  final String title;
  final String body;
  final int? cfRating;
  final String? difficulty;
  final String? sourceUrl;
  final int bonusPoints;
  final DateTime challengeDate;

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
        id: json['id'] as String,
        codeforcesId: json['codeforces_id'] as String?,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        cfRating: json['cf_rating'] as int?,
        difficulty: json['difficulty'] as String?,
        sourceUrl: json['source_url'] as String?,
        bonusPoints: json['bonus_points'] as int? ?? 0,
        challengeDate:
            DateTime.tryParse(json['challenge_date'] as String? ?? '') ??
                DateTime.now(),
      );
}

class ChallengeAttempt {
  const ChallengeAttempt({required this.isSolved, required this.solvedAt});

  final bool isSolved;
  final DateTime? solvedAt;

  factory ChallengeAttempt.fromJson(Map<String, dynamic> json) =>
      ChallengeAttempt(
        isSolved: json['is_solved'] as bool? ?? false,
        solvedAt: DateTime.tryParse(json['solved_at'] as String? ?? ''),
      );
}

/// `GET /api/challenges/today` — the challenge plus everything the screen
/// needs to say what the viewer can actually do with it.
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
  });

  final int rank;
  final DateTime? solvedAt;
  final UserSummary user;

  factory ChallengeSolver.fromJson(Map<String, dynamic> json) => ChallengeSolver(
        rank: json['rank'] as int? ?? 0,
        solvedAt: DateTime.tryParse(json['solved_at'] as String? ?? ''),
        user: UserSummary.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// What the server wants submitted to prove a Codeforces handle is yours.
class CodeforcesVerification {
  const CodeforcesVerification({
    required this.handle,
    required this.codeforcesId,
    required this.problemUrl,
    required this.windowMinutes,
  });

  final String handle;
  final String codeforcesId;
  final String problemUrl;
  final int windowMinutes;

  factory CodeforcesVerification.fromJson(Map<String, dynamic> json) =>
      CodeforcesVerification(
        handle: json['handle'] as String? ?? '',
        codeforcesId: json['codeforces_id'] as String? ?? '',
        problemUrl: json['problem_url'] as String? ?? '',
        windowMinutes: json['window_minutes'] as int? ?? 30,
      );
}
