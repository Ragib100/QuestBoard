import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Leaderboard', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              _buildFilterTabs(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return _LeaderTile(
                      rank: index + 1,
                      name: index == 0 ? 'John Doe' : (index == 1 ? 'Sarah Khan' : 'User_${index + 1}'),
                      pts: '${2500 - (index * 150)} pts',
                      isMe: index == 2,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tab('Top Users', true),
          _tab('This Week', false),
          _tab('This Month', false),
          _tab('All Time', false),
        ],
      ),
    );
  }

  Widget _tab(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: active ? const Color(0xFF0066FF) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: active ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _LeaderTile extends StatelessWidget {
  final int rank;
  final String name, pts;
  final bool isMe;
  const _LeaderTile({required this.rank, required this.name, required this.pts, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFE0F2FE) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isMe ? const Color(0xFF0066FF).withOpacity(0.3) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: rank <= 3 ? const Color(0xFFF1F5F9) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(rank.toString(), style: TextStyle(fontWeight: FontWeight.bold, color: rank <= 3 ? const Color(0xFF0066FF) : const Color(0xFF64748B)))),
          ),
          const SizedBox(width: 16),
          const CircleAvatar(radius: 20, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, size: 20, color: Color(0xFF94A3B8))),
          const SizedBox(width: 16),
          Text(name, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF0066FF), borderRadius: BorderRadius.circular(4)), child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
          ],
          const Spacer(),
          Text(pts, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0066FF))),
        ],
      ),
    );
  }
}
