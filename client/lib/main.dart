import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app/auth/post_login_router.dart';
import 'app/dashboard.dart';
import 'app/intro.dart';
import 'app/profile/profile_create.dart';
import 'app/common/reset_password.dart';
import 'config/supabase_config.dart';
import 'core/app_colors.dart';
import 'core/motion.dart';
import 'core/widgets/brand_art.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // runApp first, bootstrap second. `dotenv.load` reads a file and
  // `Supabase.initialize` restores the stored session — which usually means
  // refreshing an expired token over the network. Awaiting both here held the
  // *operating system's* splash on screen for all of it, so the app looked
  // frozen on something we do not control and cannot put a progress bar on.
  // Now our own splash paints on the first frame and the wait happens behind
  // it (decisions.md D42).
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.isSupabaseConfigured});

  /// Skips the bootstrap and forces the answer. Tests only: it is the one way
  /// to reach [ConfigurationRequiredScreen] without a `.env` on disk. Null in
  /// production, where [_MyAppState._bootstrap] works it out.
  final bool? isSupabaseConfigured;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  final _navigatorKey = GlobalKey<NavigatorState>();

  late final Future<bool> _bootstrap = _start();

  /// Loads the env and brings Supabase up. Returns whether the app is
  /// configured at all.
  Future<bool> _start() async {
    final forced = widget.isSupabaseConfigured;
    if (forced != null) return forced;

    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // A missing .env is a setup problem, not a crash — the configuration
      // screen says so, and saying it beats a red frame on first launch.
      return false;
    }

    if (!SupabaseConfig.isConfigured) return false;

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    _watchAuth();
    return true;
  }

  @override
  void initState() {
    super.initState();
    // Deep links need no Supabase, so they are armed immediately; _watchAuth
    // cannot be, and runs at the end of _start instead.
    _initDeepLinks();
  }

  /// supabase_flutter parses the recovery link itself and only then emits
  /// [AuthChangeEvent.passwordRecovery]. Navigating on a timer instead — as this
  /// used to — raced that work and landed on the form with no session, so
  /// `updateUser` failed with "Auth session missing".
  void _watchAuth() {
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const ResetPassword()),
          (route) => false,
        );
      }
    });
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

      // reset-callback is deliberately not handled here: _watchAuth navigates
      // once the recovery session actually exists.
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
        home: FutureBuilder<bool>(
          future: _bootstrap,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _SplashView();
            }
            return snapshot.data == true
                ? const _Launch()
                : const ConfigurationRequiredScreen();
          },
        ),
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
      textTheme: _buildTextTheme(baseTheme.textTheme),
      cardTheme: CardThemeData(
        color: AppColors.surface,
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
        fillColor: AppColors.surface,
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

      // Material 3 tints the app bar grey the moment content scrolls under it,
      // so without scrolledUnderElevation: 0 every bar in the app changes colour
      // mid-scroll.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(16),
        elevation: 0,
      ),
      // elevation: 0 — design-system.md allows no shadows anywhere. The nav bar
      // gets its separation from a top border drawn by the shell instead.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
      // Without this the leaderboard period toggle renders in stock M3
      // seed-tinted lavender, which is the only non-blue chrome in the app.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? AppColors.primary
                  : AppColors.surface),
          foregroundColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : AppColors.textSecondary),
          side: const WidgetStatePropertyAll(
              BorderSide(color: AppColors.border)),
          textStyle: WidgetStatePropertyAll(
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12))),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle:
              GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle:
              GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        contentTextStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.subtleFill,
        circularTrackColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle:
            GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: GoogleFonts.inter(fontSize: 12, color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary),
    );
  }

  /// The type scale. Outfit for chrome and numbers, Inter for body — never a
  /// third family (docs/design-system.md).
  ///
  /// Screens still carry local `GoogleFonts.*` calls, which win over this theme,
  /// so adding it is backwards-compatible; sites migrate to `Theme.of(context)
  /// .textTheme` opportunistically.
  TextTheme _buildTextTheme(TextTheme base) {
    TextStyle outfit(double size, FontWeight weight, {Color? color}) =>
        GoogleFonts.outfit(
          fontSize: size,
          fontWeight: weight,
          color: color ?? AppColors.textPrimary,
          height: size >= 28 ? 1.1 : null,
        );

    TextStyle inter(double size, {FontWeight? weight, Color? color}) =>
        GoogleFonts.inter(
          fontSize: size,
          fontWeight: weight,
          color: color ?? AppColors.textPrimary,
        );

    return GoogleFonts.interTextTheme(base).copyWith(
      displayLarge: outfit(56, FontWeight.bold),
      displayMedium: outfit(44, FontWeight.bold),
      displaySmall: outfit(38, FontWeight.bold),
      headlineLarge: outfit(32, FontWeight.bold),
      headlineMedium: outfit(28, FontWeight.bold),
      headlineSmall: outfit(24, FontWeight.bold),
      titleLarge: outfit(20, FontWeight.bold),
      titleMedium: outfit(18, FontWeight.w600),
      titleSmall: outfit(16, FontWeight.w600),
      bodyLarge: inter(16),
      bodyMedium: inter(14),
      bodySmall: inter(13, color: AppColors.textSecondary),
      labelLarge: outfit(16, FontWeight.bold),
      labelMedium: inter(13, weight: FontWeight.w600),
      labelSmall: inter(12, color: AppColors.textSecondary),
    );
  }
}

/// Decides the first screen: the landing page for signed-out visitors, or —
/// for a restored session — the dashboard or onboarding, depending on whether
/// the profile was ever completed.
/// Where a cold start lands: the landing page, or straight into the app.
///
/// Deliberately synchronous. This used to `await landingScreenForCurrentUser()`,
/// which calls `GET /users/me` purely to tell a fully onboarded user apart from
/// one who quit halfway through signup — so every launch sat on the splash for
/// a network round trip (up to [ApiClient.fastTimeout], and longer than that in
/// wall-clock terms against a sleeping free-tier dyno). The dashboard *already*
/// calls `/users/me` when it mounts, so this was the same request twice, the
/// first one blocking.
///
/// The rare half-onboarded case is handled where it is discovered instead:
/// [Dashboard] redirects to [ProfileCreate] when that call comes back 404.
/// [goToLanding] still resolves it up front, because straight after a login tap
/// there is nothing on screen to flash and the user is already expecting a wait.
class _Launch extends StatelessWidget {
  const _Launch();

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentSession == null) {
      return const Intro();
    }
    return const Dashboard();
  }
}

/// Shown while [_Launch] resolves the restored session — which is the very first
/// thing anyone sees after the Android splash hands over, and on a cold start
/// against a sleeping server it holds the screen for several seconds.
///
/// It carries [BrandArt], the same mark as the landing and auth screens, so the
/// app opens on something of its own rather than a flat placeholder disc. The
/// wordmark is wrapped in a scale-down [FittedBox] and the whole column is
/// padded and centred: before that the text sat in a bare full-bleed `Column`
/// with no horizontal padding, so a large system font setting ran it off both
/// edges of a phone.
///
/// The indefinite [LinearProgressIndicator] here is an uncapped animation, so
/// `pumpAndSettle` on any tree containing it would never return. `widget_test`
/// does now pump this widget — it is the first frame of every launch, forced
/// flag or not — but only ever with `pump()`, and one frame later the tree has
/// replaced it. Do not `pumpAndSettle` a tree that still has it mounted.
/// [FadeSlideIn] around the mark is fine either way — it is one finite tween.
class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Otherwise the mark drifts to the middle of a 1400px desktop
            // window with nothing around it.
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  // 4:5 rather than an even split, so the block sits a little
                  // above the optical centre — which is where the eye looks
                  // for it on a screen this empty.
                  const Spacer(flex: 4),
                  FadeSlideIn(
                    // Mark, wordmark, tagline and loader are one block. The
                    // loader used to be pinned to the foot of the screen with
                    // a Spacer between, which on a tall window left a whole
                    // dead half-page between the logo and the only moving
                    // thing on it.
                    child: Column(
                      children: [
                        const BrandArt(size: 160),
                        const SizedBox(height: 28),
                        // scaleDown, so the wordmark shrinks to fit instead of
                        // being clipped at a 2x system font scale.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('QuestBoard',
                              maxLines: 1, style: text.displaySmall),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Ask. Answer. Earn.',
                          textAlign: TextAlign.center,
                          style: text.bodyLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 40),
                        const SizedBox(
                          width: 120,
                          child: ClipRRect(
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                            child: LinearProgressIndicator(
                              minHeight: 4,
                              color: AppColors.primary,
                              backgroundColor: AppColors.primaryTint,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 5),
                ],
              ),
            ),
          ),
        ),
      ),
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
