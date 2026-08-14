import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import 'auth/login.dart';
import 'auth/signup.dart';

class Intro extends StatelessWidget {
  const Intro({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Text('QuestBoard',
                style: GoogleFonts.outfit(
                    color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const Login())),
            child: const Text('Login'),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const Signup())),
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              child: const Text('Register', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              children: [
                SizedBox(height: isWeb ? 60 : 32),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 24),
                  child: isWeb
                      ? Row(
                          children: [
                            Expanded(child: _buildHero(context, isWeb)),
                            const Expanded(child: _HeroArt()),
                          ],
                        )
                      : _buildHero(context, isWeb),
                ),
                SizedBox(height: isWeb ? 100 : 56),
                _buildHighlights(isWeb),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isWeb) {
    return Column(
      crossAxisAlignment:
          isWeb ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          'Welcome to\nQuestBoard',
          textAlign: isWeb ? TextAlign.start : TextAlign.center,
          style: GoogleFonts.outfit(
              fontSize: isWeb ? 56 : 38,
              fontWeight: FontWeight.bold,
              height: 1.1),
        ),
        const SizedBox(height: 24),
        Text(
          'Ask. Answer. Learn. Grow.',
          style: GoogleFonts.inter(
              fontSize: isWeb ? 20 : 18, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        Text(
          'Post a question with a point bounty, get help from other students, '
          'and reward the answer that actually solved it.',
          textAlign: isWeb ? TextAlign.start : TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const Signup())),
              style: ElevatedButton.styleFrom(
                  minimumSize: Size(isWeb ? 180 : 300, 56)),
              child: const Text('Get Started'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const Login())),
              style: OutlinedButton.styleFrom(
                minimumSize: Size(isWeb ? 180 : 300, 56),
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('I already have an account',
                  style: TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
      ],
    );
  }

  /// How the app works. Deliberately not usage statistics — there are no real
  /// numbers to show yet, and inventing them would mislead people.
  Widget _buildHighlights(bool isWeb) {
    const items = [
      _Highlight(
        icon: Icons.emoji_events_outlined,
        title: 'Bounty answers',
        body: 'Attach points to a question. The answer you accept earns them.',
      ),
      _Highlight(
        icon: Icons.lightbulb_outline,
        title: 'Hints, not answers',
        body: 'The AI mentor nudges you toward the solution instead of '
            'handing it over.',
      ),
      _Highlight(
        icon: Icons.local_fire_department_outlined,
        title: 'Daily challenge',
        body: 'One problem a day, bonus points, and a leaderboard to chase.',
      ),
    ];

    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: EdgeInsets.symmetric(vertical: 60, horizontal: isWeb ? 40 : 24),
      child: Wrap(
        spacing: 32,
        runSpacing: 32,
        alignment: WrapAlignment.center,
        children: items
            .map((item) => SizedBox(width: isWeb ? 300 : 340, child: item))
            .toList(),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
              color: AppColors.primaryTint, shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        const SizedBox(height: 16),
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Text(body,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 15, height: 1.5)),
      ],
    );
  }
}

class _HeroArt extends StatelessWidget {
  const _HeroArt();

  @override
  Widget build(BuildContext context) {
    return Image.network(
      'https://illustrations.popsy.co/blue/creative-process.svg',
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.bolt_rounded, size: 200, color: AppColors.primary),
    );
  }
}
