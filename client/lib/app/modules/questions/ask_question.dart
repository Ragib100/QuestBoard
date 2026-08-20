import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/quest_service.dart';
import '../../../services/common/user_service.dart';
import '../../../core/widgets/app_snack.dart';

const _availableTags = [
  'dsa',
  'math',
  'physics',
  'chemistry',
  'calculus',
  'linear-algebra',
  'graph-theory',
  'dynamic-programming',
  'number-theory',
  'geometry',
  'data-structures',
  'algorithms',
  'probability',
  'statistics',
];

const _maxTags = 5;
const _maxBounty = 100;

class AskQuestion extends StatefulWidget {
  const AskQuestion({super.key});

  @override
  State<AskQuestion> createState() => _AskQuestionState();
}

class _AskQuestionState extends State<AskQuestion> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();

  final Set<String> _selectedTags = {};
  double _bounty = 0;
  int? _balance;
  bool _submitting = false;

  /// Set when a submit was attempted with the field blank, cleared as soon as
  /// they type. Nothing is said about length before that — the old countdown
  /// ("14 more characters needed") turned asking a question into a word count.
  String? _titleError;
  String? _bodyError;

  /// Ceilings, not targets. They match `MAX_TITLE_CHARS` / `MAX_BODY_CHARS` on
  /// the server so a paste that the server would reject cannot be typed in the
  /// first place, and they are never shown — see [LabeledField.maxCharacters].
  static const _maxTitleChars = 300;
  static const _maxBodyChars = 50000;

  @override
  void initState() {
    super.initState();
    _loadBalance();
    // Rebuild as the user types so a "required" warning clears the moment it
    // stops being true.
    _titleController.addListener(_onTyped);
    _bodyController.addListener(_onTyped);
  }

  void _onTyped() {
    setState(() {
      if (_titleController.text.trim().isNotEmpty) _titleError = null;
      if (_bodyController.text.trim().isNotEmpty) _bodyError = null;
    });
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTyped);
    _bodyController.removeListener(_onTyped);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  String get _title => _titleController.text.trim();
  String get _body => _bodyController.text.trim();
  bool get _hasDraft => _title.isNotEmpty || _body.isNotEmpty;

  /// Backing out of a half-written quest used to bin it without asking.
  Future<bool> _confirmDiscard() async {
    if (!_hasDraft) return true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard this quest?'),
        content: const Text(
            'You have not posted it yet. Leaving now loses what you wrote.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep editing')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _discardAndLeave() async {
    if (!await _confirmDiscard()) return;
    if (!mounted) return;
    Navigator.pop(context, false);
  }

  Future<void> _loadBalance() async {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) return;
    try {
      final profile = await UserService.instance.getProfile(id);
      if (mounted) setState(() => _balance = profile.points);
    } on ApiException {
      // Non-fatal: the server rejects an unaffordable bounty anyway.
    }
  }

  /// Cap the slider at what the user can actually afford.
  int get _maxAffordable =>
      _balance == null ? _maxBounty : _balance!.clamp(0, _maxBounty);

  void _notify(String message, {SnackTone tone = SnackTone.error}) {
    if (!mounted) return;
    showAppSnack(context, message, tone: tone);
  }

  Future<void> _submit() async {
    final title = _title;
    final body = _body;

    // Both fields are required; neither has a length to reach. The warning
    // lands under the field that is actually empty rather than as a snackbar
    // the user has to map back onto the form.
    setState(() {
      _titleError = title.isEmpty ? 'Give your quest a title.' : null;
      _bodyError = body.isEmpty ? 'Describe what you need help with.' : null;
    });

    if (title.isEmpty || body.isEmpty) {
      _notify('Fill in the title and the description before posting.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await QuestService.instance.create(
        title: title,
        body: body,
        tags: _selectedTags.toList(),
        bountyPoints: _bounty.round(),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _notify(e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Covers the system back gesture and the app bar's back arrow, which
      // would otherwise bin a half-written quest without asking.
      canPop: !_hasDraft,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _discardAndLeave();
      },
      child: _form(context),
    );
  }

  Widget _form(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Ask a Quest',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          if (_balance != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                  child: PointsBadge(
                      points: _balance!, label: '${_balance!} pts')),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LabeledField(
                    label: 'Title',
                    controller: _titleController,
                    helper: 'Be specific — imagine asking another student.',
                    hint: 'e.g. Why does my DP solution time out on n = 10^5?',
                    maxCharacters: _maxTitleChars,
                    errorText: _titleError,
                  ),
                  const SizedBox(height: 24),
                  LabeledField(
                    label: 'Description',
                    controller: _bodyController,
                    helper:
                        'Include everything someone needs to answer: what you '
                        'tried, and where you are stuck.',
                    hint: 'Describe the problem...',
                    maxLines: 8,
                    maxCharacters: _maxBodyChars,
                    errorText: _bodyError,
                  ),
                  const SizedBox(height: 24),
                  _tagPicker(),
                  const SizedBox(height: 28),
                  _bountyPicker(),
                  const SizedBox(height: 32),
                  _actions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tagPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tags',
            style: TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text('Pick up to $_maxTags so the right people find it.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _availableTags)
              FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (on) {
                  if (on && _selectedTags.length >= _maxTags) {
                    _notify('You can choose at most $_maxTags tags.');
                    return;
                  }
                  setState(() =>
                      on ? _selectedTags.add(tag) : _selectedTags.remove(tag));
                },
              ),
          ],
        ),
      ],
    );
  }

  /// Stacked and full-width on a phone, side by side once there is room. The
  /// primary action sits on top so it stays above the keyboard-shrunk fold.
  Widget _actions(BuildContext context) {
    // Enabled even with the form empty. A greyed-out button is a rule with no
    // explanation attached; tapping it and being told which field is missing
    // is the behaviour the user asked for.
    final post = ElevatedButton(
      onPressed: _submitting ? null : _submit,
      style: ElevatedButton.styleFrom(minimumSize: const Size(180, 52)),
      child: _submitting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2))
          : const Text('Post Quest'),
    );

    final cancel = TextButton(
      onPressed: _submitting
          ? null
          : _discardAndLeave,
      style: TextButton.styleFrom(minimumSize: const Size(0, 52)),
      child: const Text('Cancel',
          style: TextStyle(color: AppColors.textSecondary)),
    );

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 420
          ? Column(children: [post, const SizedBox(height: 4), cancel])
          : Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [cancel, const SizedBox(width: 16), post],
            ),
    );
  }

  Widget _bountyPicker() {
    final bounty = _bounty.round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Bounty',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const Spacer(),
            PointsBadge(points: bounty, label: '$bounty pts'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          bounty == 0
              ? 'Optional. A bounty gets your quest answered faster.'
              : 'Deducted now and paid to whoever you accept.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (_maxAffordable == 0 && _balance != null)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'You have no points to spend yet — earn some by answering.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          )
        else
          Slider(
            value: _bounty.clamp(0, _maxAffordable.toDouble()),
            max: _maxAffordable.toDouble(),
            divisions: _maxAffordable > 0 ? _maxAffordable : null,
            label: '$bounty',
            onChanged: (v) => setState(() => _bounty = v),
          ),
        if (_balance != null && _maxAffordable < _maxBounty)
          Text('Capped at your balance of $_balance points.',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }
}
