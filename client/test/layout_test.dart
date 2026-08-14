import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/auth/forgot_password.dart';
import 'package:client/app/auth/login.dart';
import 'package:client/app/auth/signup.dart';
import 'package:client/app/intro.dart';
import 'package:client/core/widgets/async_states.dart';
import 'package:client/core/widgets/labeled_field.dart';

/// A small phone: 360x640 logical pixels, which is what a 720px-wide device at
/// 2x density reports. The dashboard's stat tiles overflowed here by up to 117
/// pixels before they were made responsive.
const _phone = Size(360, 640);

Future<void> _pumpAt(WidgetTester tester, Widget child, Size size) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
}

void main() {
  testWidgets('landing page fits a small phone without overflowing',
      (WidgetTester tester) async {
    await _pumpAt(tester, const Intro(), _phone);
    expect(tester.takeException(), isNull);
  });

  /// The auth screens are the only way into the app, so an overflow here is a
  /// dead end rather than a cosmetic bug. Both of them stacked a logo Row and a
  /// "Don't have an account? Register" Row that did not fit a 360px phone.
  testWidgets('auth screens fit a small phone', (WidgetTester tester) async {
    for (final screen in const [Login(), Signup(), ForgotPassword()]) {
      await _pumpAt(tester, screen, _phone);
      expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
    }
  });

  testWidgets('login still fits at 320px', (WidgetTester tester) async {
    await _pumpAt(tester, const Login(), const Size(320, 560));
    expect(tester.takeException(), isNull);
    expect(find.text('Welcome Back!'), findsOneWidget);
  });

  testWidgets('the landing page always offers a way to log in',
      (WidgetTester tester) async {
    // Phones drop the app bar Register button to save width, but Login has to
    // survive: removing both once left Android with no visible entry point.
    await _pumpAt(tester, const Intro(), _phone);
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });

  testWidgets('landing page fits a wide desktop window',
      (WidgetTester tester) async {
    await _pumpAt(tester, const Intro(), const Size(1400, 900));
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty and error states fit a small phone',
      (WidgetTester tester) async {
    await _pumpAt(
      tester,
      const Scaffold(
        body: EmptyState(
          icon: Icons.explore_outlined,
          title: 'No quests yet',
          message: 'Be the first to ask something and attach a bounty to it.',
          actionLabel: 'Ask a Quest',
        ),
      ),
      _phone,
    );
    expect(tester.takeException(), isNull);

    await _pumpAt(
      tester,
      const Scaffold(
        body: ErrorState(message: 'Could not reach the server.'),
      ),
      _phone,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a four-digit points badge does not blow out its row',
      (WidgetTester tester) async {
    await _pumpAt(
      tester,
      const Scaffold(
        body: Row(
          children: [
            Expanded(child: Text('A very long quest title that keeps going')),
            PointsBadge(points: 9999, label: '9999 bounty'),
          ],
        ),
      ),
      _phone,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('vote control renders in both orientations',
      (WidgetTester tester) async {
    await _pumpAt(
      tester,
      Scaffold(
        body: Column(
          children: [
            VoteControl(count: -12, myVote: -1, onVote: (_) {}),
            VoteControl(
                count: 340, myVote: 1, horizontal: true, onVote: (_) {}),
            VoteControl(count: 0, myVote: 0, enabled: false, onVote: (_) {}),
          ],
        ),
      ),
      _phone,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('-12'), findsOneWidget);
    expect(find.text('340'), findsOneWidget);
  });

  testWidgets('a form row fits a narrow screen', (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await _pumpAt(
      tester,
      Scaffold(
        body: Row(
          children: [
            Expanded(
              child: LabeledField(
                label: 'Codeforces Handle',
                controller: controller,
                helper: 'Used to verify your daily challenge solves.',
                hint: 'e.g. tourist',
              ),
            ),
          ],
        ),
      ),
      const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
  });
}
