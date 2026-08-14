import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/auth/email_verification.dart';
import 'package:client/app/common/reset_password.dart';
import 'package:client/app/modules/daily_challenge/daily_challenge_screen.dart';
import 'package:client/app/modules/questions/browse_questions.dart';
import 'package:client/core/widgets/async_states.dart';
import 'package:client/models/quest.dart';

/// QuestBoard is mobile-first, so "does it fit a phone" is the default question
/// and the desktop layout is the variant. These tests feed every list widget the
/// worst realistic data — a long display name, a five-digit bounty, a title with
/// no spaces to break on, eight tags — at the two narrowest widths we support.
const _phone = Size(360, 640);
const _narrow = Size(320, 568);

/// [child] is a fragment, wrapped in a Scaffold for it.
Future<void> _pumpAt(WidgetTester tester, Widget child, Size size) =>
    _pumpScreen(tester, Scaffold(body: child), size);

/// [screen] already provides its own Scaffold.
Future<void> _pumpScreen(WidgetTester tester, Widget screen, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.pump();
}

UserSummary _user({String first = 'Ada', String last = 'Lovelace'}) =>
    UserSummary(
      id: 'u1',
      username: 'ada',
      firstName: first,
      lastName: last,
      imageUrl: '',
      points: 99999,
    );

Quest _quest({
  String title = 'How do I balance a red-black tree after deletion?',
  int bounty = 50,
  List<String> tags = const ['dsa'],
  UserSummary? author,
  bool solved = false,
}) =>
    Quest(
      id: 'q1',
      title: title,
      bountyPoints: bounty,
      isSolved: solved,
      viewCount: 12345,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      author: author ?? _user(),
      tags: tags,
      answerCount: 128,
      voteCount: 4321,
    );

void main() {
  /// Full screens that need no Supabase session to build. EmailVerification is
  /// the one every new signup lands on, and its unscrollable Column clipped the
  /// "Go to login" button off the bottom of a 640px phone by 83px.
  testWidgets('standalone screens fit a phone without clipping',
      (WidgetTester tester) async {
    const screens = <String, Widget>{
      'EmailVerification': EmailVerification(email: 'student@example.edu'),
      'ResetPassword': ResetPassword(),
      'DailyChallenge': DailyChallengeScreen(),
    };

    for (final entry in screens.entries) {
      for (final size in const [_phone, _narrow]) {
        await _pumpScreen(tester, entry.value, size);
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $size');
      }
    }
  });

  testWidgets('quest tile survives hostile content on a phone',
      (WidgetTester tester) async {
    final quests = [
      _quest(),
      _quest(
        title: 'Supercalifragilisticexpialidocious'
            'Antidisestablishmentarianism',
        bounty: 99999,
        solved: true,
        author: _user(
            first: 'Bartholomew', last: 'Featherstonehaugh-Cholmondeley'),
        tags: const [
          'dsa',
          'math',
          'physics',
          'chemistry',
          'calculus',
          'algorithms',
          'data-structures',
          'probability',
        ],
      ),
    ];

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(
        tester,
        ListView(
          children: [
            for (final q in quests) QuestTile(quest: q, onTap: () {}),
          ],
        ),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'at $size');
    }
  });

  testWidgets('points badges do not overflow a narrow row',
      (WidgetTester tester) async {
    await _pumpAt(
      tester,
      const Row(
        children: [
          Expanded(child: Text('A quest title that runs on and on and on')),
          PointsBadge(points: 99999),
          PointsBadge(points: -99999, label: '-99999 pts'),
        ],
      ),
      _narrow,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('async states fit the narrowest phone',
      (WidgetTester tester) async {
    const states = [
      LoadingState(),
      ErrorState(
          message: 'Could not reach the server. Check your connection and '
              'try again.'),
      EmptyState(
        icon: Icons.explore_outlined,
        title: 'Nothing tagged "data-structures"',
        message: 'Try another tag, or ask the first quest on this topic.',
        actionLabel: 'Ask a Quest',
      ),
    ];

    for (final state in states) {
      await _pumpAt(tester, state, _narrow);
      expect(tester.takeException(), isNull,
          reason: '${state.runtimeType} at $_narrow');
    }
  });

  testWidgets('a large system font scale does not break a quest tile',
      (WidgetTester tester) async {
    // Accessibility settings routinely push text to 1.5x. A layout that only
    // fits at 1.0x is broken for a real slice of users.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = _phone;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: Scaffold(
          body: ListView(
            children: [
              QuestTile(quest: _quest(), onTap: () {}),
              QuestTile(
                quest: _quest(
                  bounty: 99999,
                  solved: true,
                  author: _user(
                      first: 'Bartholomew',
                      last: 'Featherstonehaugh-Cholmondeley'),
                  tags: const ['dsa', 'graph-theory', 'data-structures'],
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
