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

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey, // fix: was publishableKey
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  // fix: must be StatefulWidget for AppLinks
  const MyApp({super.key});

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
        // For forgot password flow — will handle later
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
        navigatorKey: _navigatorKey, // needed to navigate from outside build()
        debugShowCheckedModeBanner: false,
        home: const Intro(),
      ),
    );
  }
}
