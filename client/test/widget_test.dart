import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/intro.dart';
import 'package:client/core/display_name.dart';
import 'package:client/core/widgets/labeled_field.dart';
import 'package:client/models/challenge.dart';
import 'package:client/models/quest.dart';
import 'package:client/core/widgets/search_field.dart';
import 'package:client/main.dart';
import 'package:client/app/modules/daily_challenge/problem_statement_screen.dart';

void main() {
  testWidgets('shows the configuration screen when Supabase is not set up',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isSupabaseConfigured: false));

    // One pump past the splash. Startup is asynchronous now — `main` calls
    // `runApp` before loading the env or bringing Supabase up, so the first
    // frame of the app is always the splash and the answer lands on the next
    // one. Never `pumpAndSettle` here: the splash's progress bar is an
    // indefinite animation and would never settle.
    await tester.pump();

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

  /// Quests and answers have no minimum length any more — a short question is
  /// still a question. What is left is a ceiling that bounds the row, and it
  /// is deliberately silent: a "0/50000" counter reads as a target.
  /// Signing up seeds `username` with the email the account was made with, so
  /// an account that never finished onboarding was called
  /// `saifahmedsakib@gmail.com` in a 28px page heading — and an address has no
  /// spaces, so it broke mid-token across two lines at the top of the home
  /// screen. It is also not something to put on a public quest tile.
  group('display names never show an email address', () {
    test('an email username is trimmed to its handle', () {
      expect(handleOf('saifahmedsakib@gmail.com'), 'saifahmedsakib');
      expect(
        personName(firstName: '', lastName: '', username: 'a@b.com'),
        'a',
      );
      expect(
        greetingName(firstName: '', username: 'saifahmedsakib@gmail.com'),
        'saifahmedsakib',
      );
    });

    test('a real name always wins', () {
      expect(
        personName(
            firstName: 'Saif', lastName: 'Ahmed', username: 'a@b.com'),
        'Saif Ahmed',
      );
      expect(greetingName(firstName: 'Saif', username: 'a@b.com'), 'Saif');
    });

    test('a plain handle is left alone', () {
      expect(handleOf('tourist'), 'tourist');
      // A leading '@' is a handle written the Twitter way, not a domain.
      expect(handleOf('@tourist'), '@tourist');
    });

    test('the model getters go through it', () {
      const summary = UserSummary(
        id: 'u1',
        username: 'saifahmedsakib@gmail.com',
        firstName: '',
        lastName: '',
        imageUrl: '',
        points: 0,
      );
      expect(summary.displayName, 'saifahmedsakib');
      expect(summary.displayName, isNot(contains('@')));
    });
  });

  /// The desktop fallback for a problem statement — no WebView on Linux or
  /// Windows, so no MathJax. Half the sentences in a Codeforces statement carry
  /// maths, so leaving `$$$1 \le n$$$` on screen makes the page unreadable
  /// rather than merely plain (decisions.md D45).
  group('statement text fallback', () {
    test('maths becomes readable instead of raw TeX', () {
      expect(
        htmlToText(r'<p>There are $$$n$$$ students.</p>'),
        'There are n students.',
      );
      expect(
        htmlToText(r'<p>($$$1 \le n \le 2 \cdot 10^5$$$)</p>'),
        '(1 ≤ n ≤ 2 · 10⁵)',
      );
      expect(
        htmlToText(r'<p>$$$a_1, a_2, \dots, a_n$$$</p>'),
        'a₁, a₂, …, aₙ',
      );
    });

    test('an unknown macro loses its backslash rather than shouting it', () {
      // Better to read "operatorname{lcm}(a, b)" than to print a backslash at
      // someone mid-sentence. Nothing here is pretending to be a TeX engine.
      expect(htmlToText(r'<p>$$$\unknownmacro x$$$</p>'), 'unknownmacro x');
    });

    test('a superscript with no glyph keeps its ASCII form', () {
      // ^{i+1} has no unicode equivalent, so it must stay legible rather than
      // silently losing characters.
      expect(htmlToText(r'<p>$$$2^{i+1}$$$</p>'), '2^i+1');
    });

    test('block tags become line breaks and entities are unwrapped', () {
      expect(
        htmlToText('<p>One</p><p>Two &amp; three</p>'),
        'One\n\nTwo & three',
      );
    });

    test('the worked examples are dropped but the note is kept', () {
      // The fallback renders samples itself, from the structured data, where
      // they stay exact and copyable — leaving them in the prose prints each
      // example twice.
      const html = '<div>Legend</div>'
          '<div class="sample-tests"><pre>8</pre></div>'
          '<div class="note">Explanation</div>';

      final trimmed = withoutSamples(html);
      expect(trimmed, isNot(contains('sample-tests')));
      expect(trimmed, contains('note'));
      expect(trimmed, contains('Legend'));
    });

    test('a statement with no note keeps everything before the samples', () {
      const html = '<div>Legend</div><div class="sample-tests"><pre>8</pre></div>';
      expect(withoutSamples(html), '<div>Legend</div>');
    });

    test('a statement with no samples is left alone', () {
      const html = '<div>Legend</div>';
      expect(withoutSamples(html), html);
    });
  });

  /// The second way to get a statement: Codeforces' own page, loaded on the
  /// phone and stripped down to the statement, for when the server's scrape was
  /// refused. That happens routinely in production — Cloudflare reads a
  /// datacenter IP as a robot and a phone as a person (decisions.md D47).
  group('live statement reader', () {
    test('both render paths use the same stylesheet', () {
      // If these drift, the fallback starts announcing itself as a downgrade:
      // the same problem looks like our app one day and like a scraped web
      // page the next.
      expect(
        statementDocument(const ProblemStatement(available: true, html: '<p>x</p>')),
        contains(statementCss),
      );
      expect(statementReaderScript, contains(r'--primary: #0066FF'));
    });

    test('the live reader opens no bridge into the app', () {
      // The cached path may talk to `QBCopy` because the server sanitised that
      // HTML first. This one runs inside codeforces.com, with their scripts
      // live in the same origin, so it must not name a channel at all — and a
      // channel is only reachable if something references it.
      expect(statementReaderScript, isNot(contains('QBCopy')));
      expect(statementReaderScript, isNot(contains('postMessage')));
    });

    test('the live reader keeps the limits and drops the title', () {
      // The app bar already carries the title, so the header would print it
      // twice — but the limits are the only numbers on the page that constrain
      // the solution, and removing the header wholesale took them too.
      expect(statementReaderScript, contains('.time-limit'));
      expect(statementReaderScript, contains('.memory-limit'));
      expect(statementReaderScript, contains('qb-limits'));
      expect(statementReaderScript, contains('removeChild(header)'));
    });

    test('the live reader gives up rather than rewriting a Cloudflare page', () {
      // `.problem-statement` is absent from an interstitial and from a login
      // wall. Presenting either as "the statement" would be worse than showing
      // it as it is.
      expect(
        statementReaderScript,
        contains("var s = document.querySelector('.problem-statement');"),
      );
      expect(statementReaderScript, contains('if (!s) return;'));
    });
  });

  testWidgets('LabeledField caps input without showing a counter',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabeledField(
            label: 'Title',
            controller: controller,
            maxCharacters: 10,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'x' * 40);
    await tester.pump();

    expect(controller.text.length, 10, reason: 'the cap is enforced');
    expect(find.textContaining('/10'), findsNothing,
        reason: 'no counter — the limit is a guard, not a goal');
  });

  testWidgets('LabeledField shows a required warning under the field',
      (WidgetTester tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabeledField(
            label: 'Title',
            controller: controller,
            errorText: 'Give your quest a title.',
          ),
        ),
      ),
    );

    expect(find.text('Give your quest a title.'), findsOneWidget);
  });
}
