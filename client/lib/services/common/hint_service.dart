import '../../models/ai_hint.dart';
import '../api/api_client.dart';

class HintService {
  HintService._();

  static final HintService instance = HintService._();

  final _api = ApiClient.instance;

  Future<HintStatus> status() async {
    final json = await _api.get('/ai/hint');
    return HintStatus.fromJson(json as Map<String, dynamic>);
  }

  /// Buys one hint. The server deducts the points, calls the model, and rolls
  /// the deduction back if the call fails — so a thrown [ApiException] always
  /// means nothing was charged.
  ///
  /// Generating a hint takes longer than a normal request, hence the timeout.
  Future<AiHint> forQuest(String questId) async {
    final json = await _api.post(
      '/ai/hint',
      body: {'question_id': questId},
      timeout: const Duration(seconds: 60),
    );
    return AiHint.fromJson(json as Map<String, dynamic>);
  }
}
