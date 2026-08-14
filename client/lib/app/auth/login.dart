import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/widgets/labeled_field.dart';
import '../../services/common/auth_service.dart';
import '../dashboard.dart';
import 'forgot_password.dart';
import 'signup.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!EmailValidator.validate(email)) {
      _showError('Enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      _showError('Enter your password.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.login(email: email, password: password);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Dashboard()),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not sign you in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isWeb = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Row(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: AppColors.primary, size: 32),
                          const SizedBox(width: 8),
                          Text('QuestBoard',
                              style: GoogleFonts.outfit(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text('Welcome Back!',
                          style: GoogleFonts.outfit(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Login to continue to QuestBoard.',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 32),
                      LabeledField(
                        label: 'Email Address',
                        controller: _emailController,
                        hint: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      LabeledField(
                        label: 'Password',
                        controller: _passwordController,
                        hint: 'Enter your password',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _isLoading ? null : _handleLogin(),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ForgotPassword()),
                          ),
                          child: const Text('Forgot Password?',
                              style: TextStyle(fontSize: 14)),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('LOGIN'),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? "),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const Signup()),
                              ),
                              child: const Text('Register',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold)),
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
                color: AppColors.background,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://illustrations.popsy.co/blue/work-from-home.svg',
                        width: 400,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.bolt_rounded,
                            size: 160,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 40),
                      Text('Unlock your potential',
                          style: GoogleFonts.outfit(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text(
                          'Ask, answer and earn points with fellow students.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
