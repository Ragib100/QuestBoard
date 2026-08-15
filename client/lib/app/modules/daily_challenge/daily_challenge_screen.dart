import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/reward_burst.dart';
import '../../../models/challenge.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/challenge_service.dart';
import '../profile/codeforces_verify.dart';
import '../../../core/widgets/app_snack.dart';

/// One Codeforces problem a day, worth bonus points.
///
/// The solve is not taken on trust: claiming asks the server to check the
/// user's public Codeforces submissions for an accepted verdict on this exact
/// problem, which is why the handle has to be verified first.
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  TodayChallenge? _today;
  List<ChallengeSolver> _solvers = const [];
  bool _loading = true;
  bool _claiming = false;
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
      final today = await ChallengeService.instance.today();
      if (!mounted) return;
      setState(() => (_today = today, _loading = false));
      await _loadSolvers(today.challenge.id);
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  /// The leaderboard is a nice-to-have — a failure here leaves the challenge
  /// itself perfectly usable, so it does not become the screen's error state.
  Future<void> _loadSolvers(String challengeId) async {
    try {
      final solvers = await ChallengeService.instance.leaderboard(challengeId);
      if (mounted) setState(() => _solvers = solvers);
    } on ApiException {
      // Leave the list empty.
    }
  }

  void _tell(String message, {SnackTone tone = SnackTone.error}) {
    if (!mounted) return;
    showAppSnack(context, message, tone: tone);
  }

  Future<void> _verify() async {
    final verified = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CodeforcesVerify()),
    );
    if (verified == true) await _load();
  }

  Future<void> _claim() async {
    final today = _today;
    if (today == null) return;

    setState(() => _claiming = true);
    try {
      await ChallengeService.instance.claim(today.challenge.id);
      if (mounted) {
        showRewardBurst(
          context,
          message: 'Challenge solved',
          detail: '+${today.challenge.bonusPoints} points',
        );
      }
      await _load();
    } on ApiException catch (e) {
      _tell(e.message);
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Daily Challenge',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: DailyChallengeView(
                    today: _today!,
                    solvers: _solvers,
                    claiming: _claiming,
                    onClaim: _claim,
                    onVerify: _verify,
                  ),
                ),
    );
  }
}

/// Everything the challenge screen draws once the data has arrived.
///
/// Split out from the loader so the layout can be exercised at 320px with
/// hostile data — a five-digit bounty, a long title, a wall of solvers —
/// without a server or a session (see test/mobile_layout_test.dart).
class DailyChallengeView extends StatelessWidget {
  const DailyChallengeView({
    super.key,
    required this.today,
    required this.solvers,
    this.claiming = false,
    this.onClaim,
    this.onVerify,
  });

  final TodayChallenge today;
  final List<ChallengeSolver> solvers;
  final bool claiming;
  final VoidCallback? onClaim;
  final VoidCallback? onVerify;

  @override
  Widget build(BuildContext context) {
    final c = today.challenge;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!today.isToday) _staleBanner(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (c.difficulty != null) _difficultyChip(c.difficulty!),
                if (c.cfRating != null)
                  _chip('Rated ${c.cfRating}', AppColors.subtleFill,
                      AppColors.textSecondary),
                PointsBadge(
                    points: c.bonusPoints, label: '+${c.bonusPoints} pts'),
              ],
            ),
            const SizedBox(height: 16),
            Text(c.title,
                style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            SelectableText(c.body,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 15, height: 1.6)),
            if (c.sourceUrl != null) ...[
              const SizedBox(height: 16),
              CopyableUrl(url: c.sourceUrl!),
            ],
            const SizedBox(height: 24),
            _action(),
            const SizedBox(height: 24),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            _leaderboard(),
          ],
        ),
      ),
    );
  }

  Widget _staleBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.warningDark, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Codeforces is unreachable, so this is the last challenge we '
              'stored — not today\'s. Pull to refresh in a few minutes.',
              style: TextStyle(color: AppColors.warningDark, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _action() {
    if (today.isSolved) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.successTint,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.verified_rounded, color: AppColors.successDark),
            SizedBox(width: 12),
            Expanded(
              child: Text('Solved — bonus already paid.',
                  style: TextStyle(
                      color: AppColors.successDark,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }

    if (!today.codeforcesVerified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Claiming checks your public Codeforces submissions, so we need to '
            'know which account is yours first.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onVerify,
            child: const Text('Verify Codeforces handle'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: claiming ? null : onClaim,
          child: Text(claiming
              ? 'Checking Codeforces...'
              : 'I solved it — claim ${today.challenge.bonusPoints} pts'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Solve and submit on Codeforces first. We check for an accepted '
          'verdict before paying anything.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _leaderboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text('Solvers',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            Text('${today.solverCount}',
                style: const TextStyle(color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 12),
        if (solvers.isEmpty)
          const Text('Nobody has solved this one yet. Be first.',
              style: TextStyle(color: AppColors.textSecondary))
        else
          for (final s in solvers)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text('${s.rank}',
                        style: const TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold)),
                  ),
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.subtleFill,
                    child: Text(s.user.initial,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.primary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.user.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  Widget _difficultyChip(String difficulty) {
    final (bg, fg) = switch (difficulty) {
      'easy' => (AppColors.successTint, AppColors.successDark),
      'hard' => (AppColors.dangerTint, AppColors.danger),
      _ => (AppColors.warningTint, AppColors.warningDark),
    };
    return _chip(difficulty[0].toUpperCase() + difficulty.substring(1), bg, fg);
  }

  Widget _chip(String label, Color background, Color foreground) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: foreground, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}

/// A link the user can select and copy.
///
/// The app has no browser launcher and one external link is not worth adding
/// a package for, so QuestBoard shows the URL instead of pretending to open it.
class CopyableUrl extends StatelessWidget {
  const CopyableUrl({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(url,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          IconButton(
            tooltip: 'Copy link',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                showAppSnack(context, 'Link copied.',
                    tone: SnackTone.success);
              }
            },
          ),
        ],
      ),
    );
  }
}
