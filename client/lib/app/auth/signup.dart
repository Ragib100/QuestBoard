import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_colors.dart';
import '../../core/widgets/labeled_field.dart';
import '../../services/common/auth_service.dart';
import 'email_verification.dart';
import 'login.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  // Name and the rest of the profile are collected in ProfileCreate, after the
  // email is verified — signup only needs credentials.
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _agreeTerms = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!EmailValidator.validate(email)) {
      _showError('Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showError('Use a password of at least 8 characters.');
      return;
    }
    if (password != _confirmController.text) {
      _showError('The two passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService.instance.signUp(email: email, password: password);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => EmailVerification(email: email)),
        );
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Could not create your account. Please try again.');
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
                constraints: const BoxConstraints(maxWidth: 450),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded,
                              color: AppColors.primary, size: 32),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text('QuestBoard',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Text('Create Your Account',
                          style: GoogleFonts.outfit(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                          'Verify your email, then set up your profile.',
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
                        hint: 'At least 8 characters',
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      LabeledField(
                        label: 'Confirm Password',
                        controller: _confirmController,
                        hint: 'Re-enter your password',
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) =>
                            (_isLoading || !_agreeTerms) ? null : _handleSignup(),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Checkbox(
                              value: _agreeTerms,
                              onChanged: (v) =>
                                  setState(() => _agreeTerms = v ?? false)),
                          const Expanded(
                              child: Text(
                                  'I agree to the Terms of Service and Privacy Policy',
                                  style: TextStyle(fontSize: 13))),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: (_isLoading || !_agreeTerms)
                            ? null
                            : _handleSignup,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('REGISTER'),
                      ),
                      const SizedBox(height: 24),
                      // Wrap, not Row: at a large system font scale the prompt
                      // and the link together are wider than a phone.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text("Already have an account? "),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Login()),
                            ),
                            child: const Text('Login',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
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
                        'https://illustrations.popsy.co/blue/meditating.svg',
                        width: 400,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.bolt_rounded,
                            size: 160,
                            color: AppColors.primary),
                      ),
                      const SizedBox(height: 40),
                      Text('Built by students, for students',
                          style: GoogleFonts.outfit(
                              fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text('A place where knowledge meets curiosity.',
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
