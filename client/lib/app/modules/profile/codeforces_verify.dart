import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/codeforces_web.dart';
import '../../../core/widgets/async_states.dart';
import '../../../models/challenge.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/challenge_service.dart';
import '../../../core/widgets/app_snack.dart';

/// Proves the Codeforces handle on a profile belongs to the person holding it.
///
/// Reading a handle back from the Codeforces API only shows the handle exists.
/// Only the account's owner can put a *submission* on it, so we name a problem
/// and ask for a deliberate compilation error — harmless, unambiguous, and
/// checkable. Pops `true` once the server accepts it.
class CodeforcesVerify extends StatefulWidget {
  const CodeforcesVerify({super.key});

  @override
  State<CodeforcesVerify> createState() => _CodeforcesVerifyState();
}

class _CodeforcesVerifyState extends State<CodeforcesVerify> {
  CodeforcesVerification? _task;
  bool _loading = true;
  bool _checking = false;
  String? _error;

  /// True when [_error] came from never reaching the server, rather
  /// than from the server saying no. Only the first kind is worth
  /// waiting through, and [ErrorState] draws it as a spinner.
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final task = await ChallengeService.instance.verificationChallenge();
      if (mounted) setState(() => (_task = task, _loading = false));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => (
              _error = e.message,
              _offline = e.isOffline,
              _loading = false
            ));
      }
    }
  }

  void _tell(String message, {SnackTone tone = SnackTone.error}) {
    if (!mounted) return;
    showAppSnack(context, message, tone: tone);
  }

  /// Opens Codeforces' submit form for the verification problem in the app,
  /// then checks on the way back.
  ///
  /// The two halves used to be a link out and a separate "Check now" tap
  /// minutes later, with a browser switch in between. Codeforces has no submit
  /// API (decisions.md D43), so the form has to be theirs — but it does not
  /// have to be somewhere else.
  Future<void> _submitAndCheck() async {
    final task = _task;
    if (task == null) return;

    final outcome = await openCodeforces(
      context,
      task.submitUrl,
      title: 'Verify — ${task.codeforcesId}',
      // Deliberately not compilable. That is the whole proof: only the account
      // owner can put a submission on the account, and a compile error costs
      // nothing and cannot be mistaken for a real attempt.
      prefillCode: 'QuestBoard handle verification — this will not compile.',
    );

    // A browser hand-off returns the moment it launches, so there is nothing
    // to check yet; the "Check now" button below is for that case.
    if (outcome != CodeforcesOpen.embedded || !mounted) return;
    await _check(auto: true);
  }

  Future<void> _check({bool auto = false}) async {
    setState(() => _checking = true);
    try {
      await ChallengeService.instance.confirmVerification();
      if (!mounted) return;
      _tell('Handle verified.', tone: SnackTone.success);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _tell(
        auto
            ? 'No compilation error on that problem yet — Codeforces can take '
                'a moment. Tap Check now once the verdict lands.'
            : e.message,
        tone: auto ? SnackTone.neutral : SnackTone.error,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Verify Codeforces',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load, offline: _offline)
              : CodeforcesInstructions(
                  task: _task!,
                  checking: _checking,
                  onCheck: _check,
                  onSubmit: _submitAndCheck,
                ),
    );
  }
}

/// The instruction sheet, split out from the loader so it can be laid out at
/// 320px in a widget test without a server or a session.
class CodeforcesInstructions extends StatelessWidget {
  const CodeforcesInstructions({
    super.key,
    required this.task,
    this.checking = false,
    this.onCheck,
    this.onSubmit,
  });

  final CodeforcesVerification task;
  final bool checking;
  final VoidCallback? onCheck;

  /// Opens the submit form in the app and checks on the way back. Null in
  /// tests, where the primary button falls back to [onCheck].
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Prove the handle is yours',
                  style: GoogleFonts.outfit(
                      fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Anyone can type a handle into a form. A submission on the '
                'account is something only you can make.',
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 24),
              _step(1,
                  'Tap the button below. Codeforces opens here in the app — '
                  'sign in as ${task.handle} if it asks.'),
              _step(
                  2,
                  'The source box is already filled with something that will '
                  'not compile. Pick any language and press Submit.'),
              _step(
                  3,
                  'Close it. We check for the COMPILATION ERROR verdict on the '
                  'way back — it has to land within ${task.windowMinutes} '
                  'minutes.'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: checking ? null : (onSubmit ?? onCheck),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(checking ? 'Checking…' : 'Submit on Codeforces'),
              ),
              const SizedBox(height: 8),
              // The manual path. On Linux and Windows there is no in-app
              // WebView, so the button above opens a browser and returns
              // immediately — this is what closes the loop there. It is also
              // the retry when a verdict was still queued a moment ago.
              TextButton(
                onPressed: checking ? null : onCheck,
                child: const Text('Already submitted? Check now'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Nothing is charged, and nothing is sent without you: we fill '
                'the box, you press Submit. On our side we only ever read your '
                'public submission list.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _step(int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: AppColors.primaryTint,
            child: Text('$number',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textPrimary, height: 1.5)),
          ),
        ],
      ),
    );
  }

}
