import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../core/widgets/app_snack.dart';
import '../../core/widgets/async_states.dart';
import '../../core/widgets/skeletons.dart';
import '../../core/widgets/search_field.dart';
import '../../models/quest.dart';
import '../../services/api/api_client.dart';
import '../../services/common/admin_service.dart';
import '../../services/common/quest_service.dart';
import '../modules/questions/browse_questions.dart';
import '../modules/questions/question_detail.dart';

/// Moderation over the whole quest feed.
///
/// There are no "flagged" tabs because there is no reporting feature — nothing
/// in the app lets a user flag anything, so a review queue would always be
/// empty and would imply a workflow that does not exist. This lists the real
/// feed, searchable, with the one moderation action the API actually has.
class ContentModeration extends StatefulWidget {
  const ContentModeration({super.key});

  @override
  State<ContentModeration> createState() => _ContentModerationState();
}

class _ContentModerationState extends State<ContentModeration> {
  final List<Quest> _quests = [];

  bool _loading = true;
  String? _error;
  String _search = '';
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _onSearch(String term) {
    setState(() => _search = term);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await QuestService.instance.list(search: _search, limit: 50);
      if (!mounted) return;
      setState(() {
        _quests
          ..clear()
          ..addAll(page.items);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => (_error = e.message, _loading = false));
    }
  }

  Future<void> _delete(Quest quest) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this quest?'),
        content: Text(
          '"${quest.title}" and every answer on it will be removed. '
          '${quest.isSolved ? 'Its bounty has already been paid out and stays with the helper.' : 'Its bounty goes back to the author.'} '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyId = quest.id);
    try {
      await AdminService.instance.deleteQuest(quest.id);
      if (!mounted) return;
      setState(() {
        _quests.removeWhere((q) => q.id == quest.id);
        _busyId = null;
      });
      showAppSnack(context, 'Quest deleted.', tone: SnackTone.success);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      showAppSnack(context, e.message, tone: SnackTone.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text('Quests',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: SearchField(
                  hintText: 'Search quests',
                  onChanged: _onSearch,
                ),
              ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) return ListSkeleton(count: 4, item: QuestTileSkeleton.new);
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_quests.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_outlined,
        title: _search.isEmpty ? 'No quests yet' : 'No match for "$_search"',
        message: _search.isEmpty
            ? 'There is nothing to moderate until someone posts.'
            : 'Try a different word.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _quests.length,
        itemBuilder: (context, i) => ModeratedQuestTile(
          quest: _quests[i],
          busy: _busyId == _quests[i].id,
          onOpen: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => QuestionDetail(questId: _quests[i].id)),
          ).then((_) => _load()),
          onDelete: () => _delete(_quests[i]),
        ),
      ),
    );
  }
}

/// A quest as moderation sees it: the normal tile plus a delete action.
class ModeratedQuestTile extends StatelessWidget {
  const ModeratedQuestTile({
    super.key,
    required this.quest,
    required this.busy,
    required this.onOpen,
    required this.onDelete,
  });

  final Quest quest;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuestTile(quest: quest, onTap: onOpen),
        Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 20),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy ? null : onDelete,
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_outline, size: 18),
              label: const Text('Force-delete'),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}
