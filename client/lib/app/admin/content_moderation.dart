import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ContentModeration extends StatelessWidget {
  const ContentModeration({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text('Content Moderation', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
          bottom: const TabBar(
            tabs: [Tab(text: 'Flagged Questions'), Tab(text: 'Flagged Answers')],
            labelColor: Color(0xFF0066FF),
            indicatorColor: Color(0xFF0066FF),
            unselectedLabelColor: Color(0xFF64748B),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: TabBarView(
              children: [
                _buildList('Question'),
                _buildList('Answer'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(String type) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 5,
      itemBuilder: (context, index) => _moderationCard(type, index),
    );
  }

  Widget _moderationCard(String type, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(4)), child: const Text('Pending Review', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold))),
              const Spacer(),
              const Text('Reported by 3 users', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text('$type content snippet #$index goes here. This might contain offensive or spam content.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), foregroundColor: Colors.red), child: const Text('Delete Content'))),
              const SizedBox(width: 16),
              Expanded(child: ElevatedButton(onPressed: () {}, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF22C55E)), child: const Text('Approve Content'))),
            ],
          ),
        ],
      ),
    );
  }
}
