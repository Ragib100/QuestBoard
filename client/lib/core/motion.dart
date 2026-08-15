import 'package:flutter/material.dart';

/// The QuestBoard motion vocabulary. Single source of truth for durations and
/// curves — see docs/design-system.md.
///
/// This file exists for the same reason [AppColors] does (decisions.md D13): the
/// alternative is every screen picking its own 250ms/easeInOut until the app
/// looks hand-assembled. Everything here is built on Flutter SDK primitives —
/// there is no animation package, and per decisions.md D25 there should not be.
///
/// ## The rule every animation in this app follows
///
/// **Animate opacity and transform. Never animate a value the layout measures.
/// Nothing repeats forever.**
///
/// `test/mobile_layout_test.dart` pumps a single frame at 320px and asserts no
/// overflow. [Opacity] and [Transform] do not change the parent's constraints at
/// any frame, so the geometry that test measures is identical from frame 0 to
/// completion. Tween a height or a font size instead and the test would be
/// measuring a layout that never actually appears on screen.
///
/// The second half matters just as much: a pending `Timer` fails a `testWidgets`
/// body outright, and an uncapped `controller.repeat()` makes `pumpAndSettle()`
/// time out. Every animation here is one-shot or cycle-capped.
class AppMotion {
  const AppMotion._();

  /// Press feedback, hover, chip selection.
  static const fast = Duration(milliseconds: 120);

  /// Colour changes, cross-fades, most state transitions.
  static const base = Duration(milliseconds: 200);

  /// Page transitions, list entry, expand/collapse.
  static const slow = Duration(milliseconds: 320);

  /// Number roll-up.
  static const count = Duration(milliseconds: 700);

  /// One-shot reward flourish.
  static const celebrate = Duration(milliseconds: 900);

  /// Entry and the default for anything arriving on screen.
  static const standard = Curves.easeOutCubic;

  /// Anything leaving.
  static const exit = Curves.easeIn;

  /// Overshoots past its end value, so it is only ever safe on a scale or an
  /// offset — never on something the parent measures.
  static const pop = Curves.easeOutBack;

  /// Delay between adjacent items in a staggered list.
  static const stagger = Duration(milliseconds: 40);

  /// Stagger stops compounding after this many items. Uncapped, a 20-row list
  /// takes 800ms before the last row appears, which reads as lag rather than
  /// choreography.
  static const maxStaggerIndex = 6;
}

/// A page route that fades and slides in from the right.
///
/// Drop-in replacement for `MaterialPageRoute` at `Navigator.push` sites. Driven
/// by the route's own animation, which is finite — no new test risk over the
/// stock route it replaces.
Route<T> appRoute<T>(WidgetBuilder builder) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.slow,
    reverseTransitionDuration: AppMotion.base,
    pageBuilder: (context, _, __) => builder(context),
    transitionsBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: AppMotion.standard,
        reverseCurve: AppMotion.exit,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.06, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Fades and lifts [child] into place once, optionally staggered by [index].
///
/// Wrap at the *call site* rather than inside the tile itself, so widgets that
/// existing tests pump directly keep rendering unchanged.
///
/// Implemented with [TweenAnimationBuilder], which runs once from begin to end
/// and then holds no ticker — the stagger is an [Interval] on that single tween,
/// not a `Future.delayed`, precisely so nothing is left pending at the end of a
/// test.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) {
    final steps = index.clamp(0, AppMotion.maxStaggerIndex);
    final delayMs = steps * AppMotion.stagger.inMilliseconds;
    final totalMs = AppMotion.slow.inMilliseconds + delayMs;
    final start = delayMs / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(start, 1, curve: AppMotion.standard),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
      ),
      child: child,
    );
  }
}

/// Cross-fades whenever [index] changes, without rebuilding [child].
///
/// Wraps the dashboard's existing [IndexedStack] rather than replacing it. An
/// `AnimatedSwitcher` keyed on the tab index looks identical and is the obvious
/// thing to reach for, but it destroys element identity on every tap — which
/// re-runs each tab's `initState` network call and throws away all four scroll
/// positions. Passing the stack straight through as [child] keeps it mounted.
class TabTransition extends StatefulWidget {
  const TabTransition({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<TabTransition> createState() => _TabTransitionState();
}

class _TabTransitionState extends State<TabTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    value: 1,
  );

  @override
  void didUpdateWidget(TabTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    // forward(), never repeat() — one finite run per tab tap.
    if (oldWidget.index != widget.index) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: _controller, child: widget.child);
}

/// An integer that rolls up to its new value when the value changes.
///
/// [TweenAnimationBuilder] with a null `begin` does *not* animate on first
/// build — it only animates once the end value changes. That is exactly what we
/// want on both counts: widget tests construct these views once and so render
/// the full worst-case number on frame 0, while the real screens build with a
/// placeholder before their `_load()` returns and roll up when data lands.
///
/// Set [animateFromZero] only on screens no test pumps.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.style,
    this.animateFromZero = false,
    this.maxLines = 1,
  });

  final int value;
  final TextStyle? style;
  final bool animateFromZero;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(
        begin: animateFromZero ? 0 : null,
        end: value.toDouble(),
      ),
      duration: AppMotion.count,
      curve: AppMotion.standard,
      builder: (context, v, _) => Text(
        v.round().toString(),
        style: style,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
