import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:email_validator/email_validator.dart';
import '../../services/common/auth_service.dart';
import 'signup.dart';
import 'forgot_password.dart';
import '../dashboard.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both email and password.")),
      );
      return;
    }
    if (!EmailValidator.validate(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await AuthService.instance.login(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception("Login failed.");
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Dashboard()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          // 1. Background Glow Effects
          const Background(),

          // 2. Main Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    const SizedBox(height: 60),

                    // --- Header Section ---
                    const LogoSection(),
                    const SizedBox(height: 40),

                    // --- Login Card Section ---
                    LoginCard(
                      emailController: _emailController,
                      passwordController: _passwordController,
                      onLogin: handleLogin,
                      isLoading: _isLoading,
                      emailFocus: _emailFocus,
                      passwordFocus: _passwordFocus,
                    ),

                    const SizedBox(height: 30),

                    // --- Footer Section ---
                    const FooterSection(),
                    const SizedBox(height: 20),
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

class LogoSection extends StatelessWidget {
  const LogoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo with Glow
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(102, 58, 115, 237),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Image.asset('assets/images/logo.png', width: 120, height: 120),
        ),
        const SizedBox(height: 20),
        Text(
          'QUESTBOARD',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFFDAE3EE),
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Level up your problem-solving',
          style: GoogleFonts.inter(
            color: const Color(0xFF958DA1),
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class LoginCard extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final VoidCallback onLogin;
  final bool isLoading;
  final FocusNode emailFocus;
  final FocusNode passwordFocus;

  const LoginCard({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.onLogin,
    required this.isLoading,
    required this.emailFocus,
    required this.passwordFocus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22), // Dark card color
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome Back',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in to continue your quest',
            style: GoogleFonts.inter(
              color: const Color(0xFF958DA1),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),

          // Email Field
          CustomTextField(
            hintText: 'Email Address',
            icon: Icons.mail_outline,
            controller: emailController,
            focusNode: emailFocus,
            enabled: !isLoading,
            textInputAction: TextInputAction.next,
            keyboardType: TextInputType.emailAddress,
            onSubmitted: (_) {
              FocusScope.of(context).requestFocus(passwordFocus);
            },
          ),
          const SizedBox(height: 16),

          // Password Field
          CustomTextField(
            hintText: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            controller: passwordController,
            focusNode: passwordFocus,
            enabled: !isLoading,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => isLoading ? null : onLogin(),
          ),

          // Forgot Password
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ForgotPassword(),
                  ),
                );
              },
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.inter(
                  color: const Color(0xFF7C3AED),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sign In Button
          Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF22D3EE)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ElevatedButton(
              onPressed: isLoading ? null : onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'SIGN IN',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.bolt, color: Colors.white, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // OR Divider
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'OR',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF958DA1),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.grey.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Social Buttons
          Row(
            children: [
              Expanded(
                child: SocialButton(
                  label: 'Google',
                  iconPath: 'assets/icons/google.png',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SocialButton(
                  label: 'GitHub',
                  iconPath: 'assets/icons/github.png',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper Widget for Text Fields
class CustomTextField extends StatefulWidget {
  final String hintText;
  final IconData icon;
  final bool isPassword;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool enabled;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const CustomTextField({
    super.key,
    required this.hintText,
    required this.icon,
    this.isPassword = false,
    this.controller,
    this.focusNode,
    this.enabled = true,
    this.textInputAction,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      controller: widget.controller,
      obscureText: _obscureText,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      onSubmitted: widget.onSubmitted,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: Color(0xFF5B636D), fontSize: 14),
        prefixIcon: Icon(widget.icon, color: const Color(0xFF7C3AED), size: 20),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF5B636D),
                ),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF0D1117),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF7C3AED)),
        ),
      ),
    );
  }
}

// Helper Widget for Social Buttons
class SocialButton extends StatelessWidget {
  final String label;
  final String iconPath;

  const SocialButton({super.key, required this.label, required this.iconPath});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xFF1C2128),
        side: const BorderSide(color: Color(0xFF30363D)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (label == 'GitHub')
            ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              child: Image.asset(
                iconPath,
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
            )
          else
            Image.asset(iconPath, width: 26, height: 26, fit: BoxFit.contain),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class FooterSection extends StatefulWidget {
  const FooterSection({super.key});

  @override
  State<FooterSection> createState() => _FooterSectionState();
}

class _FooterSectionState extends State<FooterSection> {
  late final TapGestureRecognizer _signupRecognizer;

  @override
  void initState() {
    super.initState();
    _signupRecognizer = TapGestureRecognizer()
      ..onTap = () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Signup()),
        );
      };
  }

  @override
  void dispose() {
    _signupRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: GoogleFonts.inter(color: const Color(0xFF958DA1), fontSize: 13),
        children: [
          const TextSpan(text: "Don't have an account? "),
          TextSpan(
            text: 'Join the Quest',
            recognizer: _signupRecognizer,
            style: GoogleFonts.spaceGrotesk(
              color: const Color(0xFF7C3AED),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class Background extends StatelessWidget {
  const Background({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset('assets/images/background_img.png', fit: BoxFit.cover),
    );
  }
}
