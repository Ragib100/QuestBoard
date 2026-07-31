import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          'Hall of Fame',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildTopThree(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 20,
              itemBuilder: (context, index) {
                if (index < 3) return const SizedBox.shrink();
                return _buildLeaderboardTile(index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161B22),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTopUser('Knight_Dev', '2nd', 450, 80, const Color(0xFFC0C0C0)),
          _buildTopUser('QuestMaster', '1st', 600, 100, const Color(0xFFFFD700)),
          _buildTopUser('CodeWizard', '3rd', 380, 70, const Color(0xFFCD7F32)),
        ],
      ),
    );
  }

  Widget _buildTopUser(
      String name, String rank, int pts, double size, Color color) {
    return Column(
      children: [
        Text(
          rank,
          style: GoogleFonts.spaceGrotesk(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const CircleAvatar(
            backgroundColor: Color(0xFF0D1117),
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          '$pts XP',
          style: GoogleFonts.inter(
            color: const Color(0xFF7C3AED),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardTile(int rank) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Row(
        children: [
          Text(
            '#$rank',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF958DA1),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFF21262D),
            child: Icon(Icons.person, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Text(
            'User_Hero_$rank',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            '${1000 - (rank * 20)} XP',
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF7C3AED),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
