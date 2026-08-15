import '../../models/challenge.dart';
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

  /// Asks the server to check Codeforces for an accepted submission and pay
  /// the bonus. Throws [ApiException] with the reason when it has not.
  Future<ChallengeAttempt> claim(String challengeId) async {
    final json = await _api.post('/challenges/$challengeId/solve');
    return ChallengeAttempt.fromJson(json as Map<String, dynamic>);
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
