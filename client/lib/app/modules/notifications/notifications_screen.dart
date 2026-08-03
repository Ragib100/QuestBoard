import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Text(
          'Notifications',
          style: GoogleFonts.spaceGrotesk(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.separated(
        itemCount: 15,
        separatorBuilder: (context, index) =>
            const Divider(color: Color(0xFF30363D), height: 1),
        itemBuilder: (context, index) {
          return _buildNotificationItem(index);
        },
      ),
    );
  }

  Widget _buildNotificationItem(int index) {
    final types = ['reply', 'upvote', 'streak', 'system'];
    final type = types[index % 4];

    IconData icon;
    Color iconColor;
    String title;
    String body;

    switch (type) {
      case 'reply':
        icon = Icons.reply;
        iconColor = Colors.blue;
        title = 'New Answer';
        body = 'someone replied to your quest about animations.';
        break;
      case 'upvote':
        icon = Icons.thumb_up;
        iconColor = Colors.orange;
        title = 'Quest Upvoted';
        body = 'Your quest has reached 20 upvotes!';
        break;
      case 'streak':
        icon = Icons.local_fire_department;
        iconColor = Colors.red;
        title = 'Streak Maintained';
        body = 'You have completed your daily challenge 5 days in a row!';
        break;
      default:
        icon = Icons.info;
        iconColor = Colors.purple;
        title = 'System Update';
        body = 'QuestBoard v2.1 is now live with new features.';
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: GoogleFonts.spaceGrotesk(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        body,
        style: GoogleFonts.inter(
          color: const Color(0xFF8B949E),
          fontSize: 13,
        ),
      ),
      trailing: const Text(
        '2h',
        style: TextStyle(color: Color(0xFF484F58), fontSize: 11),
      ),
    );
  }
}
