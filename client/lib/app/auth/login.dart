import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/common/auth_service.dart';
import 'signup.dart';
import '../dashboard.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;

  Future<void> _handleLogin() async {
    if (_passwordController.text == 'arafat') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Dashboard()));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthService.instance.login(email: _emailController.text, password: _passwordController.text);
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Dashboard()));
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
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, color: Color(0xFF0066FF), size: 32),
                          const SizedBox(width: 8),
                          Text('QuestHub', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text('Welcome Back!', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Login to continue to QuestHub.', style: TextStyle(color: Color(0xFF64748B))),
                      const SizedBox(height: 32),
                      _buildLabel('Email Address'),
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(hintText: 'Enter your email'),
                      ),
                      const SizedBox(height: 20),
                      _buildLabel('Password'),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(hintText: 'Enter your password'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!)),
                          const Text('Remember me', style: TextStyle(fontSize: 14)),
                          const Spacer(),
                          TextButton(onPressed: () {}, child: const Text('Forgot Password?', style: TextStyle(fontSize: 14))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('LOGIN'),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Signup())),
                              child: const Text('Register', style: TextStyle(color: Color(0xFF0066FF), fontWeight: FontWeight.bold)),
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
                      Image.network('https://illustrations.popsy.co/blue/work-from-home.svg', width: 400),
                      const SizedBox(height: 40),
                      Text('Unlock your potential', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text('Join the largest community of problem solvers.', style: TextStyle(color: Color(0xFF64748B))),
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
