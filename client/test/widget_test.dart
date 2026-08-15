import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/intro.dart';
import 'package:client/core/widgets/labeled_field.dart';
import 'package:client/core/widgets/search_field.dart';
import 'package:client/main.dart';

void main() {
  testWidgets('shows the configuration screen when Supabase is not set up',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isSupabaseConfigured: false));

    expect(find.text('Configuration Required'), findsOneWidget);
    expect(find.byType(Intro), findsNothing);
  });

  testWidgets('landing page shows both entry points and no invented stats',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: Intro()));

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);

    // The landing page used to advertise "10K+" users that do not exist.
    expect(find.textContaining('K+'), findsNothing);
  });

  testWidgets('LabeledField renders its label, helper and hint',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LabeledField(
          label: 'Codeforces Handle',
          controller: controller,
          helper: 'Used to verify daily challenge solves.',
          hint: 'e.g. tourist',
        ),
      ),
    ));

    expect(find.text('Codeforces Handle'), findsOneWidget);
    expect(find.text('Used to verify daily challenge solves.'), findsOneWidget);
    expect(find.text('e.g. tourist'), findsOneWidget);
  });

  testWidgets('LabeledField obscures text and stays single-line for passwords',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LabeledField(
          label: 'Password',
          controller: controller,
          obscureText: true,
          maxLines: 4,
        ),
      ),
    ));

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.obscureText, isTrue);
    expect(field.maxLines, 1);
  });

  testWidgets('password fields can be revealed and hidden again',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LabeledField(
          label: 'Password',
          controller: controller,
          obscureText: true,
        ),
      ),
    ));

    bool isHidden() => tester.widget<TextField>(find.byType(TextField)).obscureText;

    expect(isHidden(), isTrue, reason: 'must start hidden');

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(isHidden(), isFalse);

    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pump();
    expect(isHidden(), isTrue);
  });

  testWidgets('non-password fields get no reveal toggle',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LabeledField(label: 'Username', controller: controller),
      ),
    ));

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('SearchField fires once per pause, not per keystroke',
      (WidgetTester tester) async {
    final terms = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchField(hintText: 'Search', onChanged: terms.add),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'd');
    await tester.enterText(find.byType(TextField), 'di');
    await tester.enterText(find.byType(TextField), 'dij');
    expect(terms, isEmpty, reason: 'nothing fires while still typing');

    await tester.pump(const Duration(milliseconds: 400));
    expect(terms, ['dij'], reason: 'one request for the whole burst');

    // The guard that three hand-rolled copies of this had drifted on: a
    // trailing space is the same query and must not re-run it.
    await tester.enterText(find.byType(TextField), 'dij ');
    await tester.pump(const Duration(milliseconds: 400));
    expect(terms, ['dij']);
  });

  testWidgets('SearchField clears immediately and reports it',
      (WidgetTester tester) async {
    final terms = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SearchField(
            hintText: 'Search', value: 'dijkstra', onChanged: terms.add),
      ),
    ));

    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    expect(terms, [''], reason: 'clearing must not wait out the debounce');
    expect(find.byTooltip('Clear'), findsNothing, reason: 'button hides when empty');
  });
}
