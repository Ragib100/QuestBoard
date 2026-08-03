import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BrowseQuestions extends StatelessWidget {
  const BrowseQuestions({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          'Browse Quests',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF7C3AED)),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10,
        itemBuilder: (context, index) {
          return const QuestionCard();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF7C3AED),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class QuestionCard extends StatelessWidget {
  const QuestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 12,
                backgroundColor: Color(0xFF7C3AED),
                child: Icon(Icons.person, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'Adventurer_42',
                style: GoogleFonts.inter(
                  color: const Color(0xFF958DA1),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '2h ago',
                style: GoogleFonts.inter(
                  color: const Color(0xFF484F58),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'How to implement complex animations in Flutter using CustomPainter?',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'I am trying to build a custom progress indicator with a liquid effect...',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: const Color(0xFF8B949E),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTag('Flutter'),
              const SizedBox(width: 8),
              _buildTag('Animation'),
              const Spacer(),
              const Icon(Icons.thumb_up_off_alt, size: 18, color: Color(0xFF958DA1)),
              const SizedBox(width: 4),
              const Text('24', style: TextStyle(color: Color(0xFF958DA1))),
              const SizedBox(width: 16),
              const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF958DA1)),
              const SizedBox(width: 4),
              const Text('12', style: TextStyle(color: Color(0xFF958DA1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF21262D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF58A6FF),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
