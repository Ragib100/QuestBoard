import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: !isWeb ? AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('My Profile', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ) : null,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildLeftSection()),
                const SizedBox(width: 32),
                Expanded(flex: 2, child: _buildRightSection()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              const CircleAvatar(radius: 60, backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.person, size: 60, color: Color(0xFF94A3B8))),
              const SizedBox(height: 24),
              Text('Arafat Hasan', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text('@arafathasan', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 24),
              _profileStat('Quests', '12'),
              _profileStat('Answers', '46'),
              _profileStat('Points', '1,250'),
              _profileStat('Badges', '5'),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
                child: const Text('Edit Profile'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileStat(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B))),
          Text(val, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _buildRightSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('About', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Passionate developer and problem solver. Love to build stuff with Flutter and explore new technologies.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('Recent Activity', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _activityCard('Answered a question', 'What is the difference between var and let?', '10m ago'),
        _activityCard('Asked a question', 'How to handle deep links in Flutter?', '1h ago'),
        _activityCard('Earned a badge', '7 Day Streak', '2h ago'),
      ],
    );
  }

  Widget _activityCard(String action, String target, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFF1F5F9), shape: BoxShape.circle), child: const Icon(Icons.bolt_rounded, color: Color(0xFF0066FF), size: 20)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(action, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                Text(target, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
        ],
      ),
    );
  }
}
