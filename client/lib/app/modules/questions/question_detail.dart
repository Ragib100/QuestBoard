import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../models/ai_hint.dart';
import '../../../models/quest.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/hint_service.dart';
import '../../../services/common/quest_service.dart';

class QuestionDetail extends StatefulWidget {
  const QuestionDetail({super.key, required this.questId});

  final String questId;

  @override
  State<QuestionDetail> createState() => _QuestionDetailState();
}

class _QuestionDetailState extends State<QuestionDetail> {
  final _answerController = TextEditingController();

  Quest? _quest;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  /// Null until the status call answers; the hint button stays hidden until
  /// then rather than promising something the server may not offer.
  HintStatus? _hintStatus;
  String? _hint;
  bool _hintLoading = false;

  String? get _myId => Supabase.instance.client.auth.currentUser?.id;
  bool get _isAuthor => _quest != null && _quest!.author.id == _myId;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHintStatus();
  }

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quest = await QuestService.instance.get(widget.questId);
      if (mounted) setState(() => (_quest = quest, _loading = false));
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Best effort. A signed-out reader, or a server with no model configured,
  /// simply never sees the hint button.
  Future<void> _loadHintStatus() async {
    if (_myId == null) return;
    try {
      final status = await HintService.instance.status();
      if (mounted) setState(() => _hintStatus = status);
    } on ApiException {
      // Leave it null — the button stays hidden.
    }
  }

  /// Buys one hint, after showing exactly what it costs. The server deducts
  /// and refunds in one transaction, so a failure here never leaves the user
  /// out of pocket — which is what the error message promises.
  Future<void> _askForHint() async {
    final status = _hintStatus;
    if (status == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Get an AI hint?'),
        content: Text(
          'This costs ${status.pointsCost} points and gives you a nudge, not '
          'the answer. You have ${status.hintsRemaining} '
          '${status.hintsRemaining == 1 ? 'hint' : 'hints'} left this hour.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
              child: Text('Spend ${status.pointsCost}')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _hintLoading = true);
    try {
      final hint = await HintService.instance.forQuest(widget.questId);
      if (mounted) {
        setState(() {
          _hint = hint.hintText;
          _hintStatus = HintStatus(
            available: true,
            pointsCost: hint.pointsCost,
            hintsRemaining: hint.hintsRemaining,
          );
        });
      }
    } on ApiException catch (e) {
      _notify(e.message);
    } finally {
      if (mounted) setState(() => _hintLoading = false);
    }
  }

  /// Votes update the UI immediately and roll back if the server disagrees —
  /// the round trip is too slow to wait on for something this small.
  Future<void> _voteQuest(int value) async {
    final quest = _quest;
    if (quest == null) return;

    final previous = quest;
    final optimisticMine = quest.myVote == value ? 0 : value;
    setState(() => _quest = quest.copyWith(
          myVote: optimisticMine,
          voteCount: quest.voteCount - quest.myVote + optimisticMine,
        ));

    try {
      final r = await QuestService.instance.voteQuest(quest.id, value);
      if (mounted) {
        setState(() =>
            _quest = _quest!.copyWith(voteCount: r.count, myVote: r.mine));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _quest = previous);
      _notify(e.message);
    }
  }

  Future<void> _voteAnswer(Answer answer, int value) async {
    final quest = _quest;
    if (quest == null) return;

    final previous = quest.answers;
    final optimisticMine = answer.myVote == value ? 0 : value;

    setState(() => _quest = quest.copyWith(
          answers: [
            for (final a in quest.answers)
              if (a.id == answer.id)
                a.copyWith(
                  myVote: optimisticMine,
                  voteCount: a.voteCount - a.myVote + optimisticMine,
                )
              else
                a,
          ],
        ));

    try {
      final r = await QuestService.instance.voteAnswer(answer.id, value);
      if (mounted) {
        setState(() => _quest = _quest!.copyWith(
              answers: [
                for (final a in _quest!.answers)
                  if (a.id == answer.id)
                    a.copyWith(voteCount: r.count, myVote: r.mine)
                  else
                    a,
              ],
            ));
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _quest = quest.copyWith(answers: previous));
      _notify(e.message);
    }
  }

  Future<void> _submitAnswer() async {
    final body = _answerController.text.trim();
    if (body.length < 10) {
      _notify('Write at least 10 characters so your answer is useful.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await QuestService.instance.answer(widget.questId, body);
      _answerController.clear();
      if (mounted) FocusScope.of(context).unfocus();
      await _load();
      _notify('Answer posted.');
    } on ApiException catch (e) {
      _notify(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _accept(Answer answer) async {
    final quest = _quest!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accept this answer?'),
        content: Text(
          quest.bountyPoints > 0
              ? 'This closes the quest and transfers ${quest.bountyPoints} '
                  'points to ${answer.author.displayName}. It cannot be undone.'
              : 'This closes the quest and marks the answer as accepted. It '
                  'cannot be undone.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(minimumSize: const Size(120, 44)),
              child: const Text('Accept')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await QuestService.instance.accept(answer.id);
      await _load();
      _notify(quest.bountyPoints > 0
          ? '${quest.bountyPoints} points awarded.'
          : 'Answer accepted.');
    } on ApiException catch (e) {
      _notify(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Quest Details',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _loading
          ? const LoadingState()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _content(),
      bottomSheet: (_quest == null || _quest!.isSolved || _isAuthor)
          ? null
          : _answerComposer(),
    );
  }

  Widget _content() {
    final quest = _quest!;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(quest),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VoteControl(
                    count: quest.voteCount,
                    myVote: quest.myVote,
                    enabled: !_isAuthor,
                    onVote: _voteQuest,
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: _questBody(quest)),
                ],
              ),
              const SizedBox(height: 40),
              const Divider(color: AppColors.border),
              const SizedBox(height: 24),
              Text(
                quest.answers.isEmpty
                    ? 'No answers yet'
                    : 'Answers (${quest.answers.length})',
                style: GoogleFonts.outfit(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (quest.answers.isEmpty)
                Text(
                  _isAuthor
                      ? 'Nobody has answered yet. Sharing the quest helps.'
                      : 'Be the first to answer'
                          '${quest.bountyPoints > 0 ? ' and earn ${quest.bountyPoints} points' : ''}.',
                  style: const TextStyle(color: AppColors.textSecondary),
                )
              else
                for (final a in quest.answers) _answerTile(quest, a),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(Quest quest) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppColors.subtleFill,
          child: Text(quest.author.initial,
              style: const TextStyle(color: AppColors.primary)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(quest.author.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              Text(timeAgo(quest.createdAt),
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 12)),
            ],
          ),
        ),
        if (quest.bountyPoints > 0) ...[
          PointsBadge(
              points: quest.bountyPoints, label: '${quest.bountyPoints} bounty'),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: quest.isSolved
                  ? AppColors.successTint
                  : AppColors.primaryTint,
              borderRadius: BorderRadius.circular(20)),
          child: Text(quest.isSolved ? 'Solved' : 'Open',
              style: TextStyle(
                  color: quest.isSolved
                      ? AppColors.successDark
                      : AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _questBody(Quest quest) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(quest.title,
            style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 20),
        SelectableText(quest.body,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 16, height: 1.6)),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in quest.tags)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.subtleFill,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(t,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ),
          ],
        ),
        ..._hintSection(),
      ],
    );
  }

  List<Widget> _hintSection() {
    final status = _hintStatus;
    final hint = _hint;

    if (hint != null) {
      return [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Text('AI hint',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(hint,
                  style: const TextStyle(
                      color: AppColors.textPrimary, height: 1.5)),
            ],
          ),
        ),
      ];
    }

    // Hidden entirely when hints are not configured on this server — an
    // always-visible button that only ever errors is worse than no button.
    if (status == null || !status.available) return const [];

    final exhausted = status.hintsRemaining <= 0;
    return [
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: (_hintLoading || exhausted) ? null : _askForHint,
        icon: _hintLoading
            ? const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.lightbulb_outline_rounded, size: 18),
        label: Text(
          _hintLoading
              ? 'Thinking...'
              : exhausted
                  ? 'No hints left this hour'
                  : 'Get a hint — ${status.pointsCost} pts',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    ];
  }

  Widget _answerTile(Quest quest, Answer answer) {
    final mine = answer.author.id == _myId;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: answer.isAccepted ? AppColors.success : AppColors.border,
            width: answer.isAccepted ? 2 : 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VoteControl(
            count: answer.voteCount,
            myVote: answer.myVote,
            enabled: !mine,
            onVote: (v) => _voteAnswer(answer, v),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.subtleFill,
                      child: Text(answer.author.initial,
                          style: const TextStyle(fontSize: 10)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(answer.author.displayName,
                          overflow: TextOverflow.ellipsis,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Text(timeAgo(answer.createdAt),
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                    const Spacer(),
                    if (answer.isAccepted)
                      const Icon(Icons.verified_rounded,
                          color: AppColors.success, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                SelectableText(answer.body,
                    style: const TextStyle(
                        color: AppColors.textSecondary, height: 1.5)),
                if (_isAuthor && !quest.isSolved) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _accept(answer),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(quest.bountyPoints > 0
                        ? 'Accept — award ${quest.bountyPoints} pts'
                        : 'Accept this answer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _answerComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _answerController,
                minLines: 1,
                maxLines: 5,
                decoration:
                    const InputDecoration(hintText: 'Write your answer...'),
              ),
            ),
            const SizedBox(width: 12),
            _submitting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton.filled(
                    onPressed: _submitAnswer,
                    icon: const Icon(Icons.send_rounded),
                    tooltip: 'Post answer',
                  ),
          ],
        ),
      ),
    );
  }
}
