import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'question_detail.dart';
import 'ask_question.dart';

class BrowseQuestions extends StatelessWidget {
  const BrowseQuestions({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: !isWeb ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Browse Quests', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              if (isWeb) _buildWebHeader(context),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: 8,
                  itemBuilder: (context, index) {
                    return _QuestionTile(
                      title: index % 2 == 0
                        ? 'What is the difference between var, let and const?'
                        : 'How does garbage collection work in Java?',
                      tag: index % 2 == 0 ? 'JavaScript' : 'Java',
                      time: '${index + 1}h ago',
                      author: 'Adventurer_${index + 1}',
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: !isWeb ? FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskQuestion())),
        backgroundColor: const Color(0xFF0066FF),
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
    );
  }

  Widget _buildWebHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('All Questions', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AskQuestion())),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Ask Question'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 48)),
          ),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  final String title, tag, time, author;
  const _QuestionTile({required this.title, required this.tag, required this.time, required this.author});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QuestionDetail(title: title, author: author, time: time))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, backgroundColor: const Color(0xFFF1F5F9), child: Text(author[0], style: const TextStyle(fontSize: 10))),
                const SizedBox(width: 8),
                Text(author, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                const Spacer(),
                Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                  child: Text(tag, style: const TextStyle(color: Color(0xFF0066FF), fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Text('12 answers', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                const SizedBox(width: 20),
                const Icon(Icons.remove_red_eye_outlined, size: 18, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Text('120 views', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
