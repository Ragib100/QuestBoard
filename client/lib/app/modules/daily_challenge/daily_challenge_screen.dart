import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/reward_burst.dart';
import '../../../core/widgets/code_composer.dart';
import '../../../core/widgets/code_view.dart';
import '../../../models/challenge.dart';
import '../../../models/code_submission.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/challenge_service.dart';
import '../profile/codeforces_verify.dart';
import 'past_challenges_screen.dart';
import '../../../core/widgets/app_snack.dart';

/// One Codeforces problem a day, worth bonus points — and the same screen for
/// any past challenge from the archive.
///
/// The solve is not taken on trust: claiming asks the server to check the
/// user's public Codeforces submissions for an accepted verdict on this exact
/// problem, which is why the handle has to be verified first. Submitting code
/// in the app does not change that; it records the work, it does not prove it.
///
/// Pass [challengeId] to open an archived challenge, which pays less the older
/// it is (docs/api.md, "Challenge point decay").
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key, this.challengeId});

  /// Null for today's challenge — the common entry point.
  final String? challengeId;

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  TodayChallenge? _today;
  List<ChallengeSolver> _solvers = const [];
  CodeSubmission _submission = CodeSubmission.empty;
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
      final id = widget.challengeId;
      final today = id == null
          ? await ChallengeService.instance.today()
          : await ChallengeService.instance.detail(id);
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

  Future<void> _openArchive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PastChallengesScreen()),
    );
    // A challenge claimed in the archive changes this screen's balance and
    // possibly its own solved state, so re-read rather than showing stale data.
    if (mounted) await _load();
  }

  Future<void> _claim() async {
    final today = _today;
    if (today == null) return;

    setState(() => _claiming = true);
    try {
      final attempt = await ChallengeService.instance
          .claim(today.challenge.id, submission: _submission);
      if (mounted) {
        showRewardBurst(
          context,
          message: 'Challenge solved',
          // The server is the authority on what it actually paid — an older
          // challenge pays less than its headline bounty.
          detail: '+${attempt.awardedPoints} points',
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
        title: Text(widget.challengeId == null ? 'Daily Challenge' : 'Challenge',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          // Only from today's screen: the archive is where you came from
          // otherwise, and a second entry would just loop.
          if (widget.challengeId == null)
            IconButton(
              tooltip: 'Past challenges',
              onPressed: _openArchive,
              icon: const Icon(Icons.history_rounded),
            ),
        ],
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
                    onOpenArchive:
                        widget.challengeId == null ? _openArchive : null,
                    onSubmissionChanged: (value) => _submission = value,
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
    this.onOpenArchive,
    this.onSubmissionChanged,
  });

  final TodayChallenge today;
  final List<ChallengeSolver> solvers;
  final bool claiming;
  final VoidCallback? onClaim;
  final VoidCallback? onVerify;

  /// Null when this screen *is* the archive's detail view.
  final VoidCallback? onOpenArchive;

  /// Fires as the code editor changes. Null in tests and wherever submitting
  /// is not offered.
  final ValueChanged<CodeSubmission>? onSubmissionChanged;

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
                // The decayed value, not the headline one: this is what
                // solving it actually pays today.
                PointsBadge(
                    points: c.awardPoints, label: '+${c.awardPoints} pts'),
                if (c.ageDays > 0)
                  _chip(
                      c.ageDays == 1 ? 'Yesterday' : '${c.ageDays} days ago',
                      AppColors.subtleFill,
                      AppColors.textSecondary),
              ],
            ),
            if (c.ageDays > 0) ...[
              const SizedBox(height: 10),
              _decayNote(c),
            ],
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

  /// Says plainly why an archived challenge is worth less than its headline
  /// bounty, rather than quietly showing a smaller number.
  Widget _decayNote(DailyChallenge c) {
    final atFloor = c.isAtFloor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.trending_down_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              atFloor
                  ? 'This one was worth ${c.bonusPoints} pts on its day. It has '
                      'decayed as far as it goes — ${c.awardPoints} pts is what '
                      'it pays from now on.'
                  : 'Worth ${c.bonusPoints} pts on its day, ${c.awardPoints} pts '
                      'now. Older challenges pay less each day.',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _archiveLink() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: onOpenArchive,
        icon: const Icon(Icons.history_rounded, size: 18),
        label: const Text('Past challenges'),
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
    final attempt = today.myAttempt;

    if (today.isSolved) {
      final paid = attempt?.awardedPoints ?? 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.successTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.successDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    // The amount comes from the attempt, not the challenge:
                    // a late solve paid less and the screen must not imply
                    // otherwise. 0 means it predates the stored amount.
                    paid > 0
                        ? 'Solved — $paid pts paid.'
                        : 'Solved — bonus already paid.',
                    style: const TextStyle(
                        color: AppColors.successDark,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          if (attempt != null) ..._savedSolution(attempt),
        ],
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
        if (onSubmissionChanged != null) ...[
          CodeComposer(
            label: 'Attach your solution',
            enabled: !claiming,
            initial: attempt?.submission ?? CodeSubmission.empty,
            onChanged: onSubmissionChanged!,
          ),
          const SizedBox(height: 12),
        ],
        ElevatedButton(
          onPressed: claiming ? null : onClaim,
          child: Text(claiming
              ? 'Checking Codeforces...'
              : 'I solved it — claim ${today.challenge.awardPoints} pts'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Solve and submit on Codeforces first. We check for an accepted '
          'verdict before paying anything — the code you attach here is kept '
          'with your attempt, not sent to Codeforces.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  /// The code and file stored on an attempt, shown back after the claim.
  List<Widget> _savedSolution(ChallengeAttempt attempt) {
    final submission = attempt.submission;
    if (submission.isEmpty) return const [];

    return [
      const SizedBox(height: 16),
      const Text('Your submission',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      if (submission.hasCode) ...[
        const SizedBox(height: 8),
        CodeBlock(
          code: submission.codeBody!,
          language: submission.codeLanguage,
        ),
      ],
      if (submission.hasAttachment) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: AttachmentChip(
            url: submission.attachmentUrl!,
            name: submission.attachmentName,
          ),
        ),
      ],
    ];
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
                  if (s.awardedPoints > 0) ...[
                    const SizedBox(width: 8),
                    Text('+${s.awardedPoints}',
                        style: const TextStyle(
                            color: AppColors.points,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ],
                ],
              ),
            ),
        if (onOpenArchive != null) ...[
          const SizedBox(height: 8),
          _archiveLink(),
        ],
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
