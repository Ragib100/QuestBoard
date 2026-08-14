import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_colors.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/labeled_field.dart';
import '../../../services/api/api_client.dart';
import '../../../services/common/quest_service.dart';
import '../../../services/common/user_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
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

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.length < 10) {
      _notify('Give your quest a title of at least 10 characters.');
      return;
    }
    if (body.length < 20) {
      _notify('Describe the problem in at least 20 characters.');
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
      body: Center(
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
                  ),
                  const SizedBox(height: 24),
                  _tagPicker(),
                  const SizedBox(height: 28),
                  _bountyPicker(),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.pop(context, false),
                        child: const Text('Cancel',
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size(180, 52)),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Post Quest'),
                      ),
                    ],
                  ),
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
