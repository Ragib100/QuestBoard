import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/login.dart';
import 'auth/signup.dart';

class Intro extends StatelessWidget {
  const Intro({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFF0066FF), size: 28),
            const SizedBox(width: 8),
            Text('QuestHub', style: GoogleFonts.outfit(color: const Color(0xFF1E293B), fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())), child: const Text('Login')),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Signup())),
              style: ElevatedButton.styleFrom(minimumSize: const Size(100, 40)),
              child: const Text('Register', style: TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome to\nQuestHub',
                          style: GoogleFonts.outfit(fontSize: 56, fontWeight: FontWeight.bold, height: 1.1),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Ask. Answer. Learn. Grow.',
                          style: GoogleFonts.inter(fontSize: 20, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Join our community to ask questions, share knowledge, earn points and badges, and grow together.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                        ),
                        const SizedBox(height: 40),
                        Row(
                          children: [
                            ElevatedButton(
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Signup())),
                              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 56)),
                              child: const Text('Get Started'),
                            ),
                            const SizedBox(width: 20),
                            OutlinedButton(
                              onPressed: () {},
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(180, 56),
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Learn More', style: TextStyle(color: Color(0xFF1E293B))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Image.network('https://illustrations.popsy.co/blue/creative-process.svg'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
            _buildStatsSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      color: const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('10K+', 'Questions'),
          _statItem('25K+', 'Answers'),
          _statItem('5K+', 'Users'),
          _statItem('100+', 'Challenges'),
        ],
      ),
    );
  }

  Widget _statItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF0066FF))),
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 16)),
      ],
    );
  }
}
