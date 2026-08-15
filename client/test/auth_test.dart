import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/auth/forgot_password.dart';
import 'package:client/app/auth/login.dart';
import 'package:client/app/auth/signup.dart';
import 'package:client/core/widgets/labeled_field.dart';

/// Client-side validation on the three auth screens.
///
/// These deliberately only exercise the paths that **reject** input, because
/// those are the ones that return before touching Supabase — the client talks
/// to Supabase Auth directly and there is no session in a widget test. That
/// limit is also the point: every one of these guards must fire without a
/// network round trip, or a student with no signal gets a spinner instead of
/// "enter a valid email address".
Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
}

/// Types into the field under [label]. LabeledField renders the label as its
/// own Text, so the TextField is found by walking down from it.
Future<void> _fill(WidgetTester tester, String label, String value) async {
  final field = find.descendant(
    of: find.ancestor(
      of: find.text(label),
      matching: find.byType(LabeledField),
    ),
    matching: find.byType(TextField),
  );
  expect(field, findsOneWidget, reason: 'no field labelled "$label"');
  await tester.enterText(field, value);
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  group('Login', () {
    testWidgets('rejects a malformed email before calling the API',
        (WidgetTester tester) async {
      await _pump(tester, const Login());
      await _fill(tester, 'Email Address', 'not-an-email');
      await _fill(tester, 'Password', 'whatever');
      await _tap(tester, 'LOGIN');

      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('rejects an empty password', (WidgetTester tester) async {
      await _pump(tester, const Login());
      await _fill(tester, 'Email Address', 'student@example.edu');
      await _tap(tester, 'LOGIN');

      expect(find.text('Enter your password.'), findsOneWidget);
    });

    testWidgets('offers a way to reach signup and password reset',
        (WidgetTester tester) async {
      // Both were unreachable on a phone at one point — the login screen is
      // the only entry to either.
      await _pump(tester, const Login());
      expect(find.text('Register'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
    });
  });

  group('Signup', () {
    /// The Terms checkbox gates the button, so every validation test has to
    /// tick it first — which is itself worth asserting.
    Future<void> agreeToTerms(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
    }

    testWidgets('the register button is disabled until terms are accepted',
        (WidgetTester tester) async {
      await _pump(tester, const Signup());

      final button = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('REGISTER'),
            matching: find.byType(ElevatedButton),
          ));
      expect(button.onPressed, isNull);

      await agreeToTerms(tester);
      final enabled = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('REGISTER'),
            matching: find.byType(ElevatedButton),
          ));
      expect(enabled.onPressed, isNotNull);
    });

    testWidgets('rejects a short password', (WidgetTester tester) async {
      await _pump(tester, const Signup());
      await agreeToTerms(tester);
      await _fill(tester, 'Email Address', 'student@example.edu');
      await _fill(tester, 'Password', 'short');
      await _fill(tester, 'Confirm Password', 'short');
      await _tap(tester, 'REGISTER');

      expect(find.text('Use a password of at least 8 characters.'),
          findsOneWidget);
    });

    testWidgets('rejects mismatched passwords', (WidgetTester tester) async {
      await _pump(tester, const Signup());
      await agreeToTerms(tester);
      await _fill(tester, 'Email Address', 'student@example.edu');
      await _fill(tester, 'Password', 'a-long-enough-password');
      await _fill(tester, 'Confirm Password', 'a-different-password');
      await _tap(tester, 'REGISTER');

      expect(find.text('The two passwords do not match.'), findsOneWidget);
    });
  });

  group('ForgotPassword', () {
    testWidgets('rejects a malformed email', (WidgetTester tester) async {
      await _pump(tester, const ForgotPassword());
      await _fill(tester, 'Email Address', 'nope');
      await _tap(tester, 'SEND RESET LINK');

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      // Still on the form: the "check your inbox" state must not appear for
      // an address we never sent anything to.
      expect(find.text('Check your inbox'), findsNothing);
    });
  });
}
