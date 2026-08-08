import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Notifications', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent Notifications', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () {}, child: const Text('Mark all as read', style: TextStyle(color: Color(0xFF0066FF)))),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    return _NotificationTile(index: index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final int index;
  const _NotificationTile({required this.index});

  @override
  Widget build(BuildContext context) {
    final types = ['reply', 'upvote', 'streak', 'new_user'];
    final type = types[index % 4];

    String title, body, time;
    IconData icon;
    Color color;

    switch (type) {
      case 'reply':
        title = 'John Doe answered your question';
        body = 'What is the difference between Array and ArrayList?';
        time = '10m ago';
        icon = Icons.reply_rounded;
        color = Colors.blue;
        break;
      case 'upvote':
        title = 'Your answer was upvoted';
        body = 'Explain the concept of Dependency Injection.';
        time = '1h ago';
        icon = Icons.thumb_up_rounded;
        color = Colors.orange;
        break;
      case 'streak':
        title = 'New badge earned: 7 Day Streak!';
        body = 'Keep going, you\'re on fire!';
        time = '2h ago';
        icon = Icons.verified_rounded;
        color = Colors.purple;
        break;
      default:
        title = 'Welcome to QuestHub!';
        body = 'Start by browsing some questions or asking your own.';
        time = '1d ago';
        icon = Icons.celebration_rounded;
        color = Colors.green;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                const SizedBox(height: 8),
                Text(time, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          if (index < 3) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0066FF), shape: BoxShape.circle)),
        ],
      ),
    );
  }
}
