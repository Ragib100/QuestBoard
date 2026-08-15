import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/admin/admin_dashboard.dart';
import 'package:client/app/admin/content_moderation.dart';
import 'package:client/app/admin/user_management.dart';
import 'package:client/app/auth/email_verification.dart';
import 'package:client/app/common/reset_password.dart';
import 'package:client/app/modules/daily_challenge/daily_challenge_screen.dart';
import 'package:client/app/modules/leaderboard/leaderboard_podium.dart';
import 'package:client/app/modules/profile/codeforces_verify.dart';
import 'package:client/app/modules/questions/browse_questions.dart';
import 'package:client/core/widgets/async_states.dart';
import 'package:client/core/widgets/skeletons.dart';
import 'package:client/models/admin.dart';
import 'package:client/models/challenge.dart';
import 'package:client/models/gamification.dart';
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

  /// view_count was parsed into [Quest] from the first version of the feed and
  /// then rendered nowhere for the entire life of the project. This pins it.
  testWidgets('a quest tile shows its view count', (WidgetTester tester) async {
    await _pumpAt(tester, QuestTile(quest: _quest(), onTap: () {}), _phone);
    expect(find.text('12345'), findsOneWidget);
  });

  /// The podium animates its pedestals, so a single `pump()` measures it at
  /// zero pedestal height — which is not what anyone ever sees. This settles the
  /// animation first, and runs the text scales too, because the first version of
  /// this test passed on frame 0 while the settled podium overflowed by 13px at
  /// 1.5x scale.
  testWidgets('the leaderboard podium fits a phone at every text scale',
      (WidgetTester tester) async {
    final top3 = [
      for (var i = 1; i <= 3; i++)
        LeaderboardEntry(
          rank: i,
          score: 9876543,
          user: _user(
              first: 'Bartholomew', last: 'Featherstonehaugh-Cholmondeley'),
        ),
    ];

    for (final size in const [_phone, _narrow]) {
      for (final scale in const [1.0, 1.3, 1.5, 2.0]) {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
                body: LeaderboardPodium(top3: top3, meId: 'u1')),
          ),
        ));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'at $size, text scale $scale');
      }
    }
  });

  /// `rank` comes back as 0 when the server cannot resolve one (a tie, or a
  /// weekly board with no ledger rows). The podium used to read its colours and
  /// heights straight off it, which painted all three plinths identical.
  testWidgets('the podium ranks by position, not by a missing rank field',
      (WidgetTester tester) async {
    final unranked = [
      for (var i = 0; i < 3; i++)
        LeaderboardEntry(rank: 0, score: 10, user: _user()),
    ];

    await _pumpAt(tester, LeaderboardPodium(top3: unranked), _narrow);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final place in const ['1', '2', '3']) {
      expect(find.text(place), findsOneWidget, reason: 'plinth $place');
    }
  });

  /// Skeletons pulse, and a pulse is the kind of animation that quietly makes
  /// `pumpAndSettle()` time out forever. The cap in [SkeletonPulse] is what
  /// stops that, and this test is the thing that would catch its removal.
  testWidgets('skeletons settle instead of pulsing forever',
      (WidgetTester tester) async {
    for (final size in const [_phone, _narrow]) {
      await _pumpScreen(
        tester,
        Scaffold(body: ListSkeleton(count: 4, item: QuestTileSkeleton.new)),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'at $size');
      await tester.pumpAndSettle();
    }
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

  /// The daily challenge screen loads from the API, so the layout lives in
  /// [DailyChallengeView] and is exercised here directly. The three branches
  /// of its action block are what actually differ, so all three are pumped.
  testWidgets('the daily challenge fits a phone in every state',
      (WidgetTester tester) async {
    final challenge = DailyChallenge.fromJson({
      'id': 'c1',
      'codeforces_id': '1873/D',
      'title': 'Prefix Sums with Antidisestablishmentarianism Constraints',
      'body': 'Codeforces problem 1873/D — rated 1500.\n'
          'Topics: binary search, data structures, dp, greedy, implementation, '
          'math, sortings, two pointers.\n\n'
          'Read the full statement and submit your solution on Codeforces, '
          'then come back and claim your bonus.',
      'cf_rating': 1500,
      'difficulty': 'hard',
      'source_url': 'https://codeforces.com/problemset/problem/1873/D',
      'bonus_points': 99999,
      'challenge_date': '2026-08-15',
    });

    final solvers = [
      for (var i = 1; i <= 3; i++)
        ChallengeSolver(
          rank: i,
          solvedAt: DateTime.now(),
          user: _user(
              first: 'Bartholomew', last: 'Featherstonehaugh-Cholmondeley'),
        ),
    ];

    final states = <String, TodayChallenge>{
      'unverified': TodayChallenge(
          challenge: challenge,
          isToday: true,
          solverCount: 3,
          myAttempt: null,
          codeforcesVerified: false),
      'claimable, stale': TodayChallenge(
          challenge: challenge,
          isToday: false,
          solverCount: 3,
          myAttempt: null,
          codeforcesVerified: true),
      'solved': TodayChallenge(
          challenge: challenge,
          isToday: true,
          solverCount: 4,
          myAttempt:
              ChallengeAttempt(isSolved: true, solvedAt: DateTime.now()),
          codeforcesVerified: true),
    };

    for (final entry in states.entries) {
      for (final size in const [_phone, _narrow]) {
        await _pumpAt(
          tester,
          DailyChallengeView(today: entry.value, solvers: solvers),
          size,
        );
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $size');
      }
    }
  });

  testWidgets('the Codeforces verification sheet fits a phone',
      (WidgetTester tester) async {
    const task = CodeforcesVerification(
      handle: 'a_very_long_codeforces_handle_indeed',
      codeforcesId: '1873/D',
      problemUrl: 'https://codeforces.com/problemset/problem/1873/D',
      windowMinutes: 30,
    );

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(tester, const CodeforcesInstructions(task: task), size);
      expect(tester.takeException(), isNull, reason: 'at $size');
    }
  });

  testWidgets('the admin screens fit a phone', (WidgetTester tester) async {
    const stats = AdminStats(
      // Six figures on every tile: the point supply is the number most likely
      // to grow past what a 320px tile can hold.
      totalUsers: 128400,
      suspendedUsers: 1024,
      totalQuests: 987654,
      openQuests: 45678,
      totalAnswers: 234567,
      pointsInCirculation: 9876543,
    );

    final users = [
      AdminUser(
        id: 'u1',
        username: 'bartholomew_featherstonehaugh',
        firstName: 'Bartholomew',
        lastName: 'Featherstonehaugh-Cholmondeley',
        points: 99999,
        isAdmin: true,
        isSuspended: true,
        createdAt: DateTime.now(),
      ),
      AdminUser(
        id: 'u2',
        username: 'ada',
        firstName: '',
        lastName: '',
        points: 0,
        isAdmin: false,
        isSuspended: false,
        createdAt: DateTime.now(),
      ),
    ];

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(
        tester,
        AdminDashboardView(stats: stats, onOpen: (_) {}),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'dashboard at $size');

      // Both rows at once: an admin who is also suspended carries two chips
      // and the button, which is what pushes the Wrap onto a second run.
      await _pumpAt(
        tester,
        ListView(
          children: [
            for (final user in users)
              AdminUserTile(
                  user: user, busy: false, onToggleSuspended: () {}),
            ModeratedQuestTile(
              quest: _quest(bounty: 99999, solved: true),
              busy: true,
              onOpen: () {},
              onDelete: () {},
            ),
          ],
        ),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'moderation at $size');
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
