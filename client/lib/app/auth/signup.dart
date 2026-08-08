import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/common/auth_service.dart';
import 'login.dart';
import 'email_verification.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _agreeTerms = false;

  Future<void> _handleSignup() async {
    if (!_agreeTerms) return;
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signUp(email: _emailController.text, password: _passwordController.text);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EmailVerification()));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFF0066FF), size: 32),
                          const SizedBox(width: 8),
                          Text('QuestHub', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text('Create Your Account', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Join the QuestHub community today.', style: TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 32),
                      _buildLabel('Full Name'),
                      TextField(controller: _nameController, decoration: const InputDecoration(hintText: 'Enter your name')),
                      const SizedBox(height: 20),
                      _buildLabel('Email Address'),
                      TextField(controller: _emailController, decoration: const InputDecoration(hintText: 'Enter your email')),
                      const SizedBox(height: 20),
                      _buildLabel('Password'),
                      TextField(controller: _passwordController, obscureText: true, decoration: const InputDecoration(hintText: 'Enter a password')),
                      const SizedBox(height: 20),
                      _buildLabel('Confirm Password'),
                      TextField(controller: _confirmController, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm your password')),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(value: _agreeTerms, onChanged: (v) => setState(() => _agreeTerms = v!)),
                          const Expanded(child: Text('I agree to the Terms of Service and Privacy Policy', style: TextStyle(fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: (_isLoading || !_agreeTerms) ? null : _handleSignup,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('REGISTER'),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Login())),
                              child: const Text('Login', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (isWeb)
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network('https://illustrations.popsy.co/blue/meditating.svg', width: 400),
                      const SizedBox(height: 40),
                      Text('Built by developers, for developers', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text('A place where knowledge meets curiosity.', style: TextStyle(color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
    );
  }
}
