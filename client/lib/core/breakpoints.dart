import 'package:flutter/widgets.dart';

/// The one width that decides phone layout from desktop layout.
///
/// QuestBoard is mobile-first (CLAUDE.md): the phone layout is the default and
/// this is the threshold for the wide variant. It lives here because it was
/// previously written out at nine call sites — and one of them disagreed.
///
/// `dashboard.dart` used `> 960` while every other screen used `> 900`, so in a
/// window between the two the shell drew the **phone** layout — bottom nav, no
/// sidebar, `embedded: true` — while the tab inside it independently decided it
/// was on a desktop and drew its wide layout. A desktop grid rendered inside a
/// phone shell is not a subtle difference, and a window that size is the
/// default on a Linux desktop.
const double wideLayoutWidth = 900;

/// True when there is room for the desktop variant.
///
/// Always ask this rather than reading `MediaQuery` directly: two screens that
/// disagree about the answer will contradict each other on screen.
bool isWideLayout(BuildContext context) =>
    MediaQuery.of(context).size.width > wideLayoutWidth;
