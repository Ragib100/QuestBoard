import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'app/intro.dart';
import 'app/profile/profile_create.dart';
import 'app/common/reset_password.dart';
import 'config/supabase_config.dart';

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
  static const ThemeMode _themeMode = ThemeMode.light;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }


  Future<void> _initDeepLinks() async {
    // Case 1 — app was closed and user tapped the link to open it
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }

    // Case 2 — app was already open in background when user tapped the link
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'io.questboard') {
      if (uri.host == 'signup-callback') {
        // Supabase SDK automatically restores session from the link
        // Wait a moment for Supabase to process the session, then navigate
        Future.delayed(const Duration(milliseconds: 300), () {
          final user = Supabase.instance.client.auth.currentUser;
          if (user != null) {
            _navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const ProfileCreate()),
              (route) => false, // clear all previous routes
            );
          }
        });
      }

      if (uri.host == 'reset-callback') {
        // For forgot password flow
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
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'QuestBoard',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.light,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.deepPurpleAccent, width: 2),
            ),
          ),
        ),
        themeMode: _themeMode,
        home: widget.isSupabaseConfigured
            ? const Intro()
            : const ConfigurationRequiredScreen(),
      ),
    );
  }
}

class ConfigurationRequiredScreen extends StatelessWidget {
  const ConfigurationRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.settings_outlined, size: 48),
              SizedBox(height: 20),
              Text(
                'QuestBoard needs configuration',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Add your Supabase URL and publishable key to client/.env, '
                'then restart the app. Copy client/.env.example as the template.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
