import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_time.dart';
import '../../../core/codeforces_web.dart';
import '../../../core/motion.dart';
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
import 'problem_statement_screen.dart';
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
  const DailyChallengeScreen({
    super.key,
    this.challengeId,
    this.embedded = false,
  });

  /// Null for today's challenge — the common entry point.
  final String? challengeId;

  /// True when the dashboard is rendering this as a tab. The shell already
  /// draws an app bar; a second one would eat 56px of a phone screen, so the
  /// archive moves to a link in the body instead of an app-bar action.
  final bool embedded;

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen> {
  TodayChallenge? _today;
  List<ChallengeSolver> _solvers = const [];
  CodeSubmission _submission = CodeSubmission.empty;
  bool _loading = true;
  bool _claiming = false;
  bool _savingCode = false;

  /// True while [_awaitVerdict] is polling Codeforces after an in-app submit.
  bool _verdictPending = false;
  String? _error;

  /// True when [_error] came from never reaching the server, rather than from
  /// the server saying no. Only the first kind is worth waiting through, and
  /// [ErrorState] draws that one as a spinner that retries itself.
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Fetches the challenge. [silent] keeps whatever is already on screen
  /// instead of blanking it to a spinner, and reports a failure as a snackbar
  /// rather than an error page.
  ///
  /// Every refresh that follows a *successful* write is silent: a claim that
  /// paid out, or code that saved, must not end up looking like it failed
  /// because the read after it timed out.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final id = widget.challengeId;
      final today = id == null
          ? await ChallengeService.instance.today()
          : await ChallengeService.instance.detail(id);
      if (!mounted) return;
      setState(() => (_today = today, _loading = false, _error = null));
      await _loadSolvers(today.challenge.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (silent) {
        _tell(e.message);
        return;
      }
      setState(() => (
            _error = e.message,
            _offline = e.isOffline,
            _loading = false
          ));
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

  /// Checks Codeforces for the verdict and pays out.
  ///
  /// [auto] marks the run that fires by itself when the submit page closes.
  /// A verdict takes a moment to land, so the honest outcome there is often
  /// "not yet" — which is worth saying gently, and is not the same thing as
  /// the user tapping Claim and being told no.
  Future<void> _claim({bool auto = false}) async {
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
      // Silent: the burst is on screen and the balance has already changed
      // server-side. A spinner over the top of it, or an error page if this
      // read fails, would both misreport a claim that worked.
      await _load(silent: true);
    } on ApiException catch (e) {
      _tell(
        auto
            ? 'Submitted. Codeforces has not returned an accepted verdict yet '
                '— tap Claim once it does.'
            : e.message,
        tone: auto ? SnackTone.neutral : SnackTone.error,
      );
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  /// Saves the code without touching Codeforces.
  ///
  /// Distinct from [_claim] on purpose: claiming refuses unless Codeforces
  /// already shows an accepted verdict, so before this existed there was no
  /// button that submitted code at all.
  Future<void> _submitCode(CodeSubmission submission) async {
    final today = _today;
    if (today == null) return;

    setState(() => _savingCode = true);
    try {
      final attempt = await ChallengeService.instance
          .saveSubmission(today.challenge.id, submission);
      _submission = submission;
      if (!mounted) return;
      // Patched in from the response instead of re-reading the screen. A
      // reload rebuilds the editor from the server mid-edit, and a reload that
      // fails would replace a save that worked with an error page.
      setState(() => _today = today.withAttempt(attempt));
      showAppSnack(context, 'Solution saved.', tone: SnackTone.success);
    } on ApiException catch (e) {
      _tell(e.message);
    } finally {
      if (mounted) setState(() => _savingCode = false);
    }
  }

  /// Waits for the Codeforces verdict after an in-app submit.
  ///
  /// A submission sits "In queue" / "Running" for a few seconds, so claiming
  /// the instant the form posts would almost always report "no accepted
  /// verdict yet" for a solve that is about to pass. This polls instead — a
  /// handful of times, a few seconds apart, and it stops the moment the answer
  /// arrives or the screen goes away.
  Future<void> _awaitVerdict() async {
    const attempts = 5;
    const gap = Duration(seconds: 4);

    setState(() => _verdictPending = true);
    try {
      for (var i = 0; i < attempts; i++) {
        await Future<void>.delayed(gap);
        if (!mounted) return;
        if (await _claimQuietly()) return;
      }
      _tell(
        'Submitted. Codeforces has not returned a verdict yet — pull to '
        'refresh, or tap Claim once it lands.',
        tone: SnackTone.neutral,
      );
    } finally {
      if (mounted) setState(() => _verdictPending = false);
    }
  }

  /// One claim attempt that says whether it worked instead of announcing it.
  Future<bool> _claimQuietly() async {
    final today = _today;
    if (today == null) return false;
    try {
      final attempt = await ChallengeService.instance
          .claim(today.challenge.id, submission: _submission);
      if (!mounted) return true;
      showRewardBurst(
        context,
        message: 'Challenge solved',
        detail: '+${attempt.awardedPoints} points',
      );
      await _load(silent: true);
      return true;
    } on ApiException {
      // Still queued, or genuinely not accepted. Either way the loop decides.
      return false;
    }
  }

  Widget _claimBar() => ChallengeActionBar(
        today: _today!,
        claiming: _claiming || _verdictPending,
        onClaim: _claim,
        onVerify: _verify,
        onOpenProblem: _openProblem,
        onSubmitOnCodeforces: _submitOnCodeforces,
        waitingForVerdict: _verdictPending,
      );

  /// Opens the real problem statement, rendered inside QuestBoard.
  ///
  /// Not the Codeforces page any more: the statement is scraped, cached and
  /// re-styled to match the app (decisions.md D45). The Codeforces page is one
  /// tap further in, from that screen's app bar.
  Future<void> _openProblem() async {
    final today = _today;
    if (today == null) return;

    await Navigator.push(
      context,
      appRoute((_) => ProblemStatementScreen(
            challengeId: today.challenge.id,
            title: today.challenge.title,
            fallbackBody: today.challenge.body,
          )),
    );
  }

  /// Opens Codeforces' submit form for this problem, with the code from the
  /// in-app editor already in it, and checks the verdict on the way back.
  ///
  /// This is the whole reason the WebView exists. Codeforces has no submit API
  /// (decisions.md D43), so the alternatives were to ask for someone's
  /// Codeforces password or to send them out to a browser and hope they came
  /// back. Their own form, hosted here, is neither.
  Future<void> _submitOnCodeforces() async {
    final today = _today;
    final url = today?.challenge.submitUrl ?? today?.challenge.sourceUrl;
    if (today == null || url == null) {
      _tell('This challenge has no problem to submit to.');
      return;
    }

    // Whatever is in the editor wins over what was last saved: the point of
    // the button is to submit what you are looking at.
    final live = _submission.hasCode ? _submission : today.myAttempt?.submission;
    final code = live?.codeBody ?? '';

    if (code.trim().isEmpty) {
      _tell('Write your solution first — there is nothing to submit yet.');
      return;
    }
    if (!mounted) return;

    final outcome = await submitToCodeforces(
      context,
      url: url,
      code: code,
      language: live?.codeLanguage,
      title: 'Submit — ${today.challenge.title}',
    );
    if (!mounted) return;

    switch (outcome) {
      case CodeforcesSubmit.submitted:
        // Codeforces has it. The verdict is seconds behind, so this waits for
        // it rather than making the user come back and press Claim.
        await _awaitVerdict();
      case CodeforcesSubmit.needsUser:
      case CodeforcesSubmit.incomplete:
        // They closed it, or finished the form by hand and we cannot tell.
        // Checking once is cheap and is right more often than not.
        await _claim(auto: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: AppColors.surface,
              elevation: 0,
              title: Text(
                  widget.challengeId == null ? 'Daily Challenge' : 'Challenge',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
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
      // The claim button used to be the last thing in a long scrolling column,
      // below the problem statement, the link, the rules and the code editor —
      // off the bottom of a phone and behind the tab bar. It was reported as
      // "there is no submit button", which is exactly what it looked like.
      // It is pinned now, the way the answer composer is on a quest.
      //
      // bottomNavigationBar, not bottomSheet: a sheet is drawn *over* the body,
      // which is why this screen used to carry 140px of guessed bottom padding
      // and still hid the last solver row whenever the bar wrapped to two
      // lines. Scaffold reserves real space for a nav bar, and moves it above
      // the keyboard instead of parking it on top of the code editor.
      bottomNavigationBar: _loading || _error != null || _today == null
          ? null
          : _claimBar(),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(
                  message: _error!, onRetry: _load, offline: _offline)
              : RefreshIndicator(
                  // The spinner is the feedback; blanking the screen behind it
                  // as well would be two loading states for one refresh.
                  onRefresh: () => _load(silent: true),
                  child: DailyChallengeView(
                    today: _today!,
                    solvers: _solvers,
                    claiming: _claiming,
                    onClaim: _claim,
                    onVerify: _verify,
                    // In a tab there is no app bar to hang the history icon
                    // on, so the link in the body is the only way through.
                    onOpenArchive: widget.challengeId == null
                        ? _openArchive
                        : null,
                    showArchiveLink: widget.embedded,
                    onSubmissionChanged: (value) => _submission = value,
                    onSubmitCode: _submitCode,
                    savingCode: _savingCode,
                    onOpenProblem: _openProblem,
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
    this.showArchiveLink = false,
    this.onSubmissionChanged,
    this.onSubmitCode,
    this.savingCode = false,
    this.onOpenProblem,
  });

  final TodayChallenge today;
  final List<ChallengeSolver> solvers;
  final bool claiming;
  final VoidCallback? onClaim;
  final VoidCallback? onVerify;

  /// Null when this screen *is* the archive's detail view.
  final VoidCallback? onOpenArchive;

  /// Draws [onOpenArchive] as a link in the body. Set when there is no app bar
  /// to put the history icon in.
  final bool showArchiveLink;

  /// Fires as the code editor changes. Null in tests and wherever submitting
  /// is not offered.
  final ValueChanged<CodeSubmission>? onSubmissionChanged;

  /// Saves the code on its own, with no Codeforces check. Null in tests.
  final Future<void> Function(CodeSubmission)? onSubmitCode;
  final bool savingCode;

  /// Opens the statement. Null in tests, where the row renders disabled.
  final VoidCallback? onOpenProblem;

  @override
  Widget build(BuildContext context) {
    final c = today.challenge;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            if (!today.isToday) _staleBanner(),
            // Grouped with the stale banner rather than buried next to the
            // editor: it explains why the pinned button at the foot of the
            // screen says "Verify Codeforces handle" instead of "Claim", and
            // that is the first question this screen raises.
            if (!today.isSolved && !today.codeforcesVerified) _verifyBanner(),
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
            const SizedBox(height: 16),
            _StatementLink(title: c.title, onOpen: onOpenProblem),
            // Above the fold when this is a tab: without an app bar the
            // history icon is gone, and the link at the foot of the solver
            // list is a long scroll away.
            if (showArchiveLink && onOpenArchive != null) _archiveLink(),
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

  /// What the body says about claiming, plus the editor that stores your code.
  ///
  /// The *claim* action itself is pinned to the bottom of the screen by
  /// [_DailyChallengeScreenState._claimBar] — this is the explanation that
  /// goes with it, and it must never duplicate that button or there are two of
  /// them and neither looks primary.
  ///
  /// The editor is offered whether or not the handle is verified. Verifying
  /// gates *claiming*, because only Codeforces can say a problem was solved;
  /// it has nothing to do with keeping a copy of your work, and
  /// `PUT /challenges/{id}/submission` does not ask for it. Hiding the editor
  /// behind it meant a new user's first sight of this screen had no submit
  /// button anywhere on it (decisions.md D40).
  Widget _action() {
    final attempt = today.myAttempt;
    final submitted = attempt != null && !attempt.submission.isEmpty
        ? attempt.submission
        : null;

    if (today.isSolved) {
      final saved = attempt == null ? const <Widget>[] : _savedSolution(attempt);
      if (saved.isEmpty) {
        return const Text(
          'Solved. You did not attach a solution to this one.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: saved,
      );
    }

    // Editor first, rules second. They used to be the other way round, which
    // put a three-step explainer and a warning panel between the problem and
    // the only thing on the screen you can actually do — about a screen and a
    // half of scrolling on a phone before the submit button appeared.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onSubmissionChanged != null) ...[
          const Text('Your solution',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            today.codeforcesVerified
                ? 'Write or upload your code and submit it — it is saved '
                    'against this challenge straight away. The bonus is still '
                    'paid on the Codeforces verdict, so claim it once you have '
                    'submitted there.'
                : 'Write or upload your code and submit it — it is saved '
                    'against this challenge straight away. Verifying your '
                    'handle is only needed to claim the bonus, not for this.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 8),
          if (submitted != null) ...[
            _submittedNote(submitted),
            const SizedBox(height: 8),
          ],
          CodeComposer(
            // Keyed on the challenge, because the composer holds the typed
            // text in its own controller: without this, opening a second
            // archived challenge reuses the element and shows the first one's
            // code as if it were yours on this problem.
            key: ValueKey('solution-${today.challenge.id}'),
            label: 'Write or upload your code',
            enabled: !claiming && !savingCode,
            initial: attempt?.submission ?? CodeSubmission.empty,
            onChanged: onSubmissionChanged!,
            onSubmit: onSubmitCode,
            submitLabel: 'Submit code',
            submitting: savingCode,
            startOpen: true,
          ),
          const SizedBox(height: 24),
        ],
        _howItWorks(),
      ],
    );
  }

  /// Why the pinned button at the foot of the screen says "Verify Codeforces
  /// handle" rather than "Claim".
  ///
  /// It also says what verifying does *not* block, because the editor further
  /// down works regardless, and an unexplained lock above an enabled submit
  /// button reads as a broken screen.
  Widget _verifyBanner() {
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
          Icon(Icons.lock_outline_rounded,
              size: 20, color: AppColors.warningDark),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Claiming the bonus checks your public Codeforces submissions, '
              'so verify which account is yours first. Writing and saving your '
              'solution here works without it.',
              style: TextStyle(
                  color: AppColors.warningDark, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Confirms that a submission is stored, so "did that save?" has an answer
  /// on the screen rather than only in a snackbar that has already gone.
  Widget _submittedNote(CodeSubmission submission) {
    final parts = <String>[
      if (submission.hasCode) 'code',
      if (submission.hasAttachment) submission.attachmentName ?? 'a file',
    ];
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 18, color: AppColors.successDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Submitted: ${parts.join(' + ')}. Editing and submitting again '
              'replaces it.',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.successDark),
            ),
          ),
        ],
      ),
    );
  }

  /// The claim rules, stated before the button rather than in the error the
  /// button produces.
  ///
  /// Two of these surprise people. The points come from Codeforces' verdict,
  /// not from anything typed into this app; and the accepted submission has to
  /// be dated on or after the challenge's own day, so a solve from last year
  /// does not count. Both were only discoverable by failing.
  Widget _howItWorks() {
    final since = formatDay(today.challenge.challengeDate);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How claiming works',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _step('1', 'Solve and submit the problem on Codeforces.'),
          _step('2',
              'Your submission has to be accepted, and dated $since or later '
              '— an older solve does not count.'),
          _step('3', 'Come back and tap claim. We check your public '
              'submissions for the verdict.'),
        ],
      ),
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$number.',
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }

  /// The code and file stored on an attempt, shown back after the claim.
  List<Widget> _savedSolution(ChallengeAttempt attempt) {
    final submission = attempt.submission;
    if (submission.isEmpty) return const [];

    return [
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
        // Only when it is not already at the top. There is one archive link
        // on this screen; which end it sits at is the only question.
        if (onOpenArchive != null && !showArchiveLink) ...[
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

/// The way into the problem statement.
///
/// It used to be a box of raw URL text with a copy button — a whole line of
/// `https://codeforces.com/problemset/problem/1873/D` spent on something nobody
/// reads — and then a link that opened Codeforces itself. The statement is
/// rendered inside the app now (D45), so this is a row that says what it opens.
class _StatementLink extends StatelessWidget {
  const _StatementLink({required this.title, this.onOpen});

  final String title;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.subtleFill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Read the full problem',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    Text('Statement, limits and examples — here in the app',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A Codeforces link: tap the row to open it in the app, or the icon to copy.
///
/// It used to be a box of raw URL text with a copy button, on the grounds that
/// the app had no browser launcher. It has had one since D37 and an in-app
/// WebView since D43, and CLAUDE.md's rule is that an external URL opens rather
/// than asking to be pasted — a whole line of
/// `https://codeforces.com/problemset/problem/1873/D` is also most of a phone's
/// width spent on something nobody reads.
///
/// Copy stays as the secondary action: on a platform with no WebView this falls
/// back to a browser, and on one with no browser to the clipboard, so making
/// that deliberate costs one icon.
class ExternalLink extends StatelessWidget {
  const ExternalLink({
    super.key,
    required this.url,
    this.label = 'Open in your browser',
  });

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.subtleFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => openCodeforces(context, url, title: label),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new_rounded,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                          Text(url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy link',
            icon: const Icon(Icons.copy_rounded, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) {
                showAppSnack(context, 'Link copied.', tone: SnackTone.success);
              }
            },
          ),
        ],
      ),
    );
  }
}


/// The pinned action at the foot of the challenge screen.
///
/// Split out and public for the same reason [DailyChallengeView] is: it has
/// three states and has to survive a 320px screen in all of them, and the
/// screen that owns it cannot be pumped without a server.
///
/// It exists at all because the claim button used to be the last thing in a
/// long scrolling column — below the statement, the link, the rules and the
/// code editor — which put it off the bottom of a phone and behind the tab
/// bar. It was reported as "there is no submit button", which is what it
/// looked like.
class ChallengeActionBar extends StatelessWidget {
  const ChallengeActionBar({
    super.key,
    required this.today,
    this.claiming = false,
    this.onClaim,
    this.onVerify,
    this.onOpenProblem,
    this.onSubmitOnCodeforces,
    this.waitingForVerdict = false,
  });

  final TodayChallenge today;
  final bool claiming;
  final VoidCallback? onClaim;
  final VoidCallback? onVerify;
  final VoidCallback? onOpenProblem;

  /// Opens Codeforces' submit form in the app. Null in tests and on the
  /// archive's detail view.
  final VoidCallback? onSubmitOnCodeforces;

  /// True while the app is polling Codeforces for the verdict of a submission
  /// it just made. The bar says what it is waiting for rather than going inert.
  final bool waitingForVerdict;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _content(),
        ),
      ),
    );
  }

  Widget _content() {
    final attempt = today.myAttempt;

    if (today.isSolved) {
      final paid = attempt?.awardedPoints ?? 0;
      return Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.successDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              paid > 0 ? 'Solved — $paid pts paid.' : 'Solved — bonus paid.',
              style: const TextStyle(
                  color: AppColors.successDark, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      );
    }

    if (!today.codeforcesVerified) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onVerify,
          child: const Text('Verify Codeforces handle'),
        ),
      );
    }

    // Submitting is the primary act and Claim is the follow-up, which is the
    // opposite of how this bar used to read. Only a Codeforces verdict pays, so
    // for anyone who has not submitted yet Claim can only ever fail — it was
    // the loud blue button telling people no.
    //
    // Reading the statement is not here: it is a row in the body, and a third
    // button does not fit 320px.
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: claiming ? null : onClaim,
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
            // Half a 360px screen minus padding does not fit much at the
            // default button size, and the label wrapped onto two lines.
            child: Text(
                waitingForVerdict
                    ? 'Waiting…'
                    : (claiming ? 'Checking…' : 'Claim'),
                maxLines: 1,
                style: const TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: claiming ? null : (onSubmitOnCodeforces ?? onOpenProblem),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Submit',
                maxLines: 1, style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8)),
          ),
        ),
      ],
    );
  }
}
