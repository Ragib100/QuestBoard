import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login.dart';

class EmailVerification extends StatelessWidget {
  const EmailVerification({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), shape: BoxShape.circle),
                  child: const Icon(Icons.mark_email_read_rounded, size: 80, color: Color(0xFF0066FF)),
                ),
                const SizedBox(height: 40),
                Text('Verify Your Email', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text(
                  'We have sent a verification link to your email address. Please check your inbox and click the link to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Login())),
                  child: const Text('GO TO LOGIN'),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () {},
                  child: const Text('Didn\'t receive the email? Resend Email', style: TextStyle(color: Color(0xFF0066FF))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
