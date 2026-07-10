import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth/login.dart';

class Intro extends StatefulWidget {
  const Intro({super.key});

  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Login()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Stack(
        children: [
          const BackgroundEffects(),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 152,
                            height: 152,
                            decoration: BoxDecoration(
                              color: const Color(0x33D2BBFF),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromARGB(102, 132, 66, 247),
                                  blurRadius: 40,
                                  spreadRadius: 10,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x667C3AED),
                                  blurRadius: 20,
                                  spreadRadius: 0,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.asset(
                                'assets/images/logo.jpg',
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),

                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.5,
                          ),
                          children: const [
                            TextSpan(text: 'Quest'),
                            TextSpan(
                              text: 'Board',
                              style: TextStyle(color: Color(0xFF7C3AED)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'LEVEL UP YOUR PROBLEM-SOLVING',
                        style: GoogleFonts.hankenGrotesk(
                          color: const Color(0xFF8B949E),
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                const LoadingIndicator(),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundEffects extends StatelessWidget {
  const BackgroundEffects({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          left: -100,
          child: Container(
            width: 600,
            height: 600,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x26958DA1), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          top: 200,
          left: -100,
          child: Container(
            width: 600,
            height: 600,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x337C3AED), Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0x4C37333E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x194A4455)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: const LinearProgressIndicator(
              value: null,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(Color(0xFF7C3AED)),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'INITIALIZING SYSTEM...',
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF958DA1),
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
