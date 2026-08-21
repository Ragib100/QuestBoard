import '../../models/challenge.dart';
import '../../models/code_submission.dart';
import '../api/api_client.dart';

class ChallengeService {
  ChallengeService._();

  static final ChallengeService instance = ChallengeService._();

  final _api = ApiClient.instance;

  /// The server creates today's challenge on the first request of the day, so
  /// this can be slower than a normal read — it may be waiting on Codeforces.
  Future<TodayChallenge> today({bool authenticated = true}) async {
    final json = await _api.get(
      '/challenges/today',
      auth: authenticated,
      timeout: const Duration(seconds: 20),
    );
    return TodayChallenge.fromJson(json as Map<String, dynamic>);
  }

  /// One challenge by id, in the same shape as [today] — how an archived
  /// challenge reuses the whole screen.
  Future<TodayChallenge> detail(String challengeId,
      {bool authenticated = true}) async {
    final json = await _api.get('/challenges/$challengeId', auth: authenticated);
    return TodayChallenge.fromJson(json as Map<String, dynamic>);
  }

  /// Past challenges, newest first. Each row already carries the decayed
  /// `awardPoints`, so the list never advertises a number the server will not
  /// pay.
  Future<ChallengePage> archive({
    int page = 1,
    int limit = 20,
    bool authenticated = true,
  }) async {
    final json = await _api.get(
      '/challenges',
      query: {'page': page, 'limit': limit},
      auth: authenticated,
    );
    return ChallengePage.fromJson(json as Map<String, dynamic>);
  }

  /// Asks the server to check Codeforces for an accepted submission and pay
  /// the award. Throws [ApiException] with the reason when it has not.
  ///
  /// [submission] is the code written or attached in the app. It is stored on
  /// the attempt either way — the verdict is what pays, but a claim made a
  /// minute too early must not discard the work.
  Future<ChallengeAttempt> claim(
    String challengeId, {
    CodeSubmission submission = CodeSubmission.empty,
  }) async {
    final json = await _api.post(
      '/challenges/$challengeId/solve',
      body: submission.toJson(),
      // Claiming waits on the public Codeforces API, which is rate limited and
      // often slow — the default 10s times out on a perfectly good claim.
      timeout: const Duration(seconds: 25),
    );
    return ChallengeAttempt.fromJson(json as Map<String, dynamic>);
  }

  /// Saves the code written or attached in the app onto the caller's attempt,
  /// without asking Codeforces anything.
  ///
  /// Separate from [claim] on purpose. `claim` refuses unless Codeforces
  /// already shows an accepted verdict, so while it was the only thing that
  /// persisted a submission there was no way to submit code before solving —
  /// which is exactly what "there is no submit button" meant.
  Future<ChallengeAttempt> saveSubmission(
    String challengeId,
    CodeSubmission submission,
  ) async {
    final json = await _api.put(
      '/challenges/$challengeId/submission',
      body: submission.toJson(),
      // A solution is a few kilobytes going to a free Render dyno that may be
      // cold. The default 10s turned a slow-but-fine save into "could not
      // reach the server" — which is what submitting felt like when it worked.
      timeout: const Duration(seconds: 20),
    );
    return ChallengeAttempt.fromJson(json as Map<String, dynamic>);
  }

  /// The real Codeforces problem statement.
  ///
  /// Never throws for "Codeforces would not give it to us" — that comes back as
  /// `available: false`, because it is a routine outcome and the screen has an
  /// honest fallback for it.
  Future<ProblemStatement> statement(String challengeId) async {
    final json = await _api.get(
      '/challenges/$challengeId/statement',
      auth: false,
      // The first reader for a given problem pays for the scrape: a request to
      // codeforces.com, on top of a possibly cold dyno. Every reader after that
      // is served from the cached copy on the row.
      timeout: const Duration(seconds: 30),
    );
    return ProblemStatement.fromJson(json as Map<String, dynamic>);
  }

  Future<List<ChallengeSolver>> leaderboard(String challengeId) async {
    final json = await _api.get('/challenges/$challengeId/leaderboard',
        auth: false);
    return [
      for (final row in json as List)
        ChallengeSolver.fromJson(row as Map<String, dynamic>),
    ];
  }

  /// Step one of handle verification: what to submit, and where.
  Future<CodeforcesVerification> verificationChallenge() async {
    final json = await _api.get('/users/me/codeforces/verification');
    return CodeforcesVerification.fromJson(json as Map<String, dynamic>);
  }

  /// Step two: checks Codeforces for the compile error. Throws with the
  /// reason when it is not there yet.
  Future<void> confirmVerification() =>
      _api.post('/users/me/codeforces/verification');
}
