import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../core/breakpoints.dart';
import '../core/motion.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/brand_art.dart';
import 'auth/login.dart';
import 'auth/signup.dart';

void _open(BuildContext context, Widget screen) {
  Navigator.push(context, appRoute((_) => screen));
}

class Intro extends StatelessWidget {
  const Intro({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isWeb = isWideLayout(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        // The wordmark yields before the actions do: an app bar that ellipsizes
        // "QuestBoard" is survivable, one that hides the Login button is not.
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 28),
            const SizedBox(width: 8),
            Flexible(
              child: Text('QuestBoard',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        // The logo plus both buttons does not fit a phone app bar, but dropping
        // them entirely leaves no way to reach Login from the top of the page.
        // Phones keep Login only; Register is the hero's primary button anyway.
        actions: isWeb
            ? [
                TextButton(
                  onPressed: () => _open(context, const Login()),
                  child: const Text('Login'),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 20.0),
                  child: ElevatedButton(
                    onPressed: () => _open(context, const Signup()),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(100, 40)),
                    child:
                        const Text('Register', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => _open(context, const Login()),
                  child: const Text('Login'),
                ),
                const SizedBox(width: 4),
              ],
      ),
      // The 1200px cap is applied per section, not to the page.
      //
      // Wrapping the whole Column in it also capped the highlights band, whose
      // whole job is to be a full-width stripe of a different colour — on a
      // wide screen it stopped 360px short of each edge and read as a
      // misaligned block floating in the middle of the page. The band is now
      // full-bleed and caps its own contents instead.
      body: SingleChildScrollView(
        child: Column(
          // Stretch, so the full-bleed highlights band actually reaches both
          // edges. The capped sections centre themselves inside it.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: isWeb ? 56 : 24),
            _capped(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isWeb ? 40 : 24),
                child: isWeb
                    ? Row(
                        children: [
                          Expanded(child: _buildHero(context, isWeb)),
                          const Expanded(child: Center(child: BrandArt(size: 300))),
                        ],
                      )
                    : _buildHero(context, isWeb),
              ),
            ),
            SizedBox(height: isWeb ? 88 : 40),
            _buildHighlights(isWeb),
          ],
        ),
      ),
    );
  }

  /// Centres [child] and stops it growing past the page's reading width.
  static Widget _capped({required Widget child}) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: child,
        ),
      );

  Widget _buildHero(BuildContext context, bool isWeb) {
    return Column(
      crossAxisAlignment:
          isWeb ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // A phone gets the mark too. [BrandArt] used to live only in the
        // desktop hero's second column, and a phone has no second column — so
        // the first screen of the app was three stacked paragraphs of grey
        // text and nothing to look at.
        if (!isWeb) ...[
          const BrandArt(size: 132),
          const SizedBox(height: 20),
        ],
        Text(
          'Welcome to\nQuestBoard',
          textAlign: isWeb ? TextAlign.start : TextAlign.center,
          style: GoogleFonts.outfit(
              fontSize: isWeb ? 56 : 36,
              fontWeight: FontWeight.bold,
              height: 1.1),
        ),
        SizedBox(height: isWeb ? 20 : 14),
        Text(
          'Ask. Answer. Learn. Grow.',
          textAlign: isWeb ? TextAlign.start : TextAlign.center,
          style: GoogleFonts.inter(
              fontSize: isWeb ? 20 : 17,
              fontWeight: FontWeight.w600,
              color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          'Post a question with a point bounty, get help from other students, '
          'and reward the answer that actually solved it.',
          textAlign: isWeb ? TextAlign.start : TextAlign.center,
          style: const TextStyle(
              color: AppColors.textSecondary, fontSize: 15, height: 1.6),
        ),
        SizedBox(height: isWeb ? 40 : 28),
        // Side by side on desktop, stacked full-width on a phone. Wrap rather
        // than Row on desktop: the two labels together need more than half of
        // a 1200px page, so a hard Row overflows instead of breaking.
        _HeroActions(isWeb: isWeb),
      ],
    );
  }

  /// How the app works. Deliberately not usage statistics — there are no real
  /// numbers to show yet, and inventing them would mislead people.
  Widget _buildHighlights(bool isWeb) {
    const items = [
      _Highlight(
        icon: Icons.emoji_events_outlined,
        title: 'Bounty answers',
        body: 'Attach points to a question. The answer you accept earns them.',
      ),
      _Highlight(
        icon: Icons.lightbulb_outline,
        title: 'Hints, not answers',
        body: 'The AI mentor nudges you toward the solution instead of '
            'handing it over.',
      ),
      _Highlight(
        icon: Icons.local_fire_department_outlined,
        title: 'Daily challenge',
        body: 'One problem a day, bonus points, and a leaderboard to chase.',
      ),
    ];

    // ColoredBox rather than a Container: the band must reach both edges of
    // the window, and its width comes from the stretched Column above it.
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: isWeb ? 64 : 40, horizontal: isWeb ? 40 : 24),
        child: _capped(
          // A Row of Expanded cards on desktop, stacked full width on a phone.
          // IntrinsicHeight because three cards of unequal text length in a
          // row leave ragged bottoms otherwise; a fixed 340px card would
          // overflow a 360px phone once padding is subtracted, which is why
          // the phone case takes whatever width is left instead.
          child: isWeb
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, item) in items.indexed) ...[
                        if (i > 0) const SizedBox(width: 24),
                        Expanded(child: FadeSlideIn(index: i, child: item)),
                      ],
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (final (i, item) in items.indexed) ...[
                      if (i > 0) const SizedBox(height: 12),
                      FadeSlideIn(index: i, child: item),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroActions extends StatelessWidget {
  const _HeroActions({required this.isWeb});

  final bool isWeb;

  @override
  Widget build(BuildContext context) {
    final signUp = ElevatedButton(
      onPressed: () => _open(context, const Signup()),
      style: ElevatedButton.styleFrom(
          minimumSize: Size(isWeb ? 180 : double.infinity, 54)),
      child: const Text('Get Started'),
    );

    final logIn = OutlinedButton(
      onPressed: () => _open(context, const Login()),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(isWeb ? 180 : double.infinity, 54),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('I already have an account',
          style: TextStyle(color: AppColors.textPrimary)),
    );

    if (!isWeb) {
      // double.infinity needs a bounded parent, which Column gives it and
      // Wrap does not.
      return Column(children: [signUp, const SizedBox(height: 12), logIn]);
    }

    return Wrap(spacing: 20, runSpacing: 12, children: [signUp, logIn]);
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    // A card, not a loose text block. The band used to be three centred
    // paragraphs floating in 32px of whitespace with no container around them,
    // which on a phone read as a long sparse scroll rather than a list of
    // three things. [AppCard] is the app's standard container — white, 1px
    // border, radius 16, no shadow (design-system.md) — and it reads against
    // the band's grey.
    //
    // The contents stay centred so the band keeps the hero's axis: a centred
    // heading above a left-aligned list was the original complaint (D39).
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
                color: AppColors.primaryTint, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
