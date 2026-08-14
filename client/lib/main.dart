import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/auth/post_login_router.dart';
import 'app/intro.dart';
import 'app/profile/profile_create.dart';
import 'app/common/reset_password.dart';
import 'config/supabase_config.dart';
import 'core/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  }

  runApp(MyApp(isSupabaseConfigured: SupabaseConfig.isConfigured));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.isSupabaseConfigured});

  final bool isSupabaseConfigured;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'io.questboard') {
      if (uri.host == 'signup-callback') {
        Future.delayed(const Duration(milliseconds: 300), () {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ProfileCreate()),
              (route) => false,
            );
          }
        });
      }

      if (uri.host == 'reset-callback') {
        Future.delayed(const Duration(milliseconds: 300), () {
          _navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const ResetPassword()),
            (route) => false,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'QuestBoard',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: widget.isSupabaseConfigured
            ? const _Launch()
            : const ConfigurationRequiredScreen(),
      ),
    );
  }

  ThemeData _buildTheme() {
    final baseTheme = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.background,
        onSurface: AppColors.textPrimary,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.displayLarge,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        titleLarge: GoogleFonts.outfit(
          textStyle: baseTheme.textTheme.titleLarge,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 54),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

/// Decides the first screen: the landing page for signed-out visitors, or —
/// for a restored session — the dashboard or onboarding, depending on whether
/// the profile was ever completed.
class _Launch extends StatefulWidget {
  const _Launch();

  @override
  State<_Launch> createState() => _LaunchState();
}

class _LaunchState extends State<_Launch> {
  late final Future<Widget> _destination = _resolve();

  Future<Widget> _resolve() async {
    if (Supabase.instance.client.auth.currentSession == null) {
      return const Intro();
    }
    return landingScreenForCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data ?? const Intro();
      },
    );
  }
}

class ConfigurationRequiredScreen extends StatelessWidget {
  const ConfigurationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.settings_outlined, size: 64, color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                'Configuration Required',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              const Text(
                'Please add your Supabase credentials to the .env file in the client directory and restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
