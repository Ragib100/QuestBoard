import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../models/challenge.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/challenge_service.dart';
import '../daily_challenge/daily_challenge_screen.dart' show CopyableUrl;

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
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await ChallengeService.instance.confirmVerification();
      if (!mounted) return;
      _tell('Handle verified.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      _tell(e.message);
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
              ? ErrorState(message: _error!, onRetry: _load)
              : CodeforcesInstructions(
                  task: _task!,
                  checking: _checking,
                  onCheck: _check,
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
  });

  final CodeforcesVerification task;
  final bool checking;
  final VoidCallback? onCheck;

  @override
  Widget build(BuildContext context) {
    return Center(
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
              _step(1, 'Sign in to Codeforces as ${task.handle}.'),
              _step(2, 'Open problem ${task.codeforcesId}.'),
              _step(
                  3,
                  'Submit anything that will not compile — a single line of '
                  'nonsense is fine. Wait for the COMPILATION ERROR verdict.'),
              _step(4,
                  'Come back within ${task.windowMinutes} minutes and tap Check.'),
              const SizedBox(height: 16),
              CopyableUrl(url: task.problemUrl),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: checking ? null : onCheck,
                child: Text(checking ? 'Checking...' : 'Check now'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nothing is charged and nothing is submitted on your behalf — '
                'we only read your public submission list.',
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
