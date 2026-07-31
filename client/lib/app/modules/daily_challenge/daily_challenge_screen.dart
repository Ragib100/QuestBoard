import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DailyChallengeScreen extends StatelessWidget {
  const DailyChallengeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          'Daily Challenge',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildChallengeCard(),
            const SizedBox(height: 32),
            _buildRewardsSection(),
            const SizedBox(height: 32),
            _buildProgressSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildChallengeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4338CA)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4338CA).withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF818CF8), size: 48),
          const SizedBox(height: 16),
          Text(
            'The Debugger\'s Maze',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Find and fix 3 memory leaks in the provided pseudo-code to earn bonus XP.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: const Color(0xFFC7D2FE),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('ACCEPT CHALLENGE'),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Rewards',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildRewardItem(Icons.bolt, '100 XP'),
            _buildRewardItem(Icons.stars, '50 Gems'),
            _buildRewardItem(Icons.shield, 'Rare Badge'),
          ],
        ),
      ],
    );
  }

  Widget _buildRewardItem(IconData icon, String label) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF7C3AED)),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Streak',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text('4/7 Days', style: TextStyle(color: Color(0xFF7C3AED))),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 4 / 7,
            backgroundColor: const Color(0xFF0D1117),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF7C3AED)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}
