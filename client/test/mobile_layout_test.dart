import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/admin/admin_dashboard.dart';
import 'package:client/app/admin/content_moderation.dart';
import 'package:client/app/admin/user_management.dart';
import 'package:client/app/auth/email_verification.dart';
import 'package:client/app/common/reset_password.dart';
import 'package:client/app/modules/daily_challenge/daily_challenge_screen.dart';
import 'package:client/app/modules/daily_challenge/past_challenges_screen.dart';
import 'package:client/app/modules/leaderboard/leaderboard_podium.dart';
import 'package:client/app/modules/profile/codeforces_verify.dart';
import 'package:client/app/modules/questions/browse_questions.dart';
import 'package:client/core/widgets/async_states.dart';
import 'package:client/core/widgets/code_composer.dart';
import 'package:client/core/widgets/code_view.dart';
import 'package:client/core/widgets/skeletons.dart';
import 'package:client/models/admin.dart';
import 'package:client/models/challenge.dart';
import 'package:client/models/code_submission.dart';
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

/// One archived challenge, priced as the server would price it at [ageDays]
/// old. [award] is passed rather than recomputed so the test states the
/// expected decay instead of duplicating the formula.
TodayChallenge _archived({
  required int ageDays,
  required int award,
  int bonus = 50,
  bool solved = false,
  bool verified = true,
}) =>
    TodayChallenge(
      challenge: DailyChallenge.fromJson({
        'id': 'c-$ageDays',
        'codeforces_id': '1873/D',
        'title': 'Antidisestablishmentarianismically'
            'Concatenated' * 2,
        'body': 'Codeforces problem 1873/D.',
        'cf_rating': 1500,
        'difficulty': 'hard',
        'source_url': 'https://codeforces.com/problemset/problem/1873/D',
        'bonus_points': bonus,
        'challenge_date': '2026-08-01',
        'award_points': award,
        'age_days': ageDays,
      }),
      isToday: false,
      solverCount: 99999,
      myAttempt: solved
          ? ChallengeAttempt(
              isSolved: true,
              solvedAt: DateTime.now(),
              awardedPoints: award,
              submission: const CodeSubmission(
                codeBody: 'int main(){return 0;}',
                codeLanguage: 'cpp',
                attachmentUrl: 'https://example.com/sol.cpp',
                attachmentName: 'sol.cpp',
              ),
            )
          : null,
      codeforcesVerified: verified,
    );

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

  /// The bottom bar went from four tabs to five when the Daily Challenge was
  /// promoted out of the overflow menu. Five is Material's maximum for a fixed
  /// bar and 320px is our narrowest screen, so this is the case that would
  /// overflow if a label ever got longer.
  testWidgets('the five-tab bottom bar fits the narrowest phone',
      (WidgetTester tester) async {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Home'),
      BottomNavigationBarItem(icon: Icon(Icons.explore_rounded), label: 'Quests'),
      BottomNavigationBarItem(
          icon: Icon(Icons.emoji_events_rounded), label: 'Ranks'),
      BottomNavigationBarItem(
          icon: Icon(Icons.track_changes_rounded), label: 'Daily'),
      BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
    ];

    for (final size in const [_phone, _narrow]) {
      await _pumpScreen(
        tester,
        Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: 3,
            type: BottomNavigationBarType.fixed,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            onTap: (_) {},
            items: items,
          ),
        ),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'bottom bar at $size');
      // Every label stays legible: a shifting bar would hide four of them.
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    }
  });

  /// As a tab there is no app bar, so the archive link and the claim rules
  /// both have to fit inside the body.
  testWidgets('the embedded daily challenge fits a phone',
      (WidgetTester tester) async {
    final entry = _archived(ageDays: 2, award: 40, bonus: 50);

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(
        tester,
        DailyChallengeView(
          today: entry,
          solvers: const [],
          showArchiveLink: true,
          onOpenArchive: () {},
          onSubmissionChanged: (_) {},
        ),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'embedded at $size');
    }

    // Content checks get a tall viewport: the screen is a lazy ListView, so on
    // a 568px phone the archive link is simply not built yet and a `findsNothing`
    // here would be about scrolling, not about the layout.
    await _pumpAt(
      tester,
      DailyChallengeView(
        today: entry,
        solvers: const [],
        showArchiveLink: true,
        onOpenArchive: () {},
        onSubmissionChanged: (_) {},
      ),
      const Size(360, 2400),
    );
    expect(find.text('Past challenges'), findsOneWidget);
    // The recency rule is stated before the button, not only in its error.
    expect(find.textContaining('older solve does not count'), findsOneWidget);
  });

  /// The claim action is pinned, and every one of its three states has to fit
  /// a 320px bar. It was reported as missing when it lived at the bottom of a
  /// scrolling column, so "is it on screen" is now the thing under test.
  testWidgets('the pinned claim bar fits a phone in every state',
      (WidgetTester tester) async {
    final states = <String, TodayChallenge>{
      'unverified': _archived(ageDays: 0, award: 50, verified: false),
      'claimable': _archived(ageDays: 0, award: 50),
      'solved': _archived(ageDays: 9, award: 99999, bonus: 99999, solved: true),
    };

    for (final entry in states.entries) {
      for (final size in const [_phone, _narrow]) {
        await _pumpAt(
          tester,
          Column(children: [
            const Spacer(),
            ChallengeActionBar(
              today: entry.value,
              onClaim: () {},
              onVerify: () {},
              onOpenProblem: () {},
            ),
          ]),
          size,
        );
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $size');
      }
    }
  });

  /// The bar shows the step you are on, not every step at once.
  ///
  /// It used to be Claim and Submit side by side, two half-width buttons of
  /// equal weight, while a third button inside the editor said "Submit code"
  /// and meant something else again. This walks the sequence instead.
  testWidgets('the action bar offers one primary action per stage',
      (WidgetTester tester) async {
    Future<void> pumpBar({
      bool hasCode = false,
      bool sent = false,
      bool waiting = false,
      int checks = 0,
    }) =>
        _pumpAt(
          tester,
          ChallengeActionBar(
            today: _archived(ageDays: 0, award: 50),
            onClaim: () {},
            onVerify: () {},
            onOpenProblem: () {},
            onSubmitOnCodeforces: () {},
            hasCode: hasCode,
            submittedToCodeforces: sent,
            waitingForVerdict: waiting,
            verdictChecksDone: checks,
            onStopWaiting: () {},
          ),
          _narrow,
        );

    // Nothing written yet: submitting is off, and the bar says why rather
    // than waiting to fail when pressed.
    await pumpBar();
    final empty = find.widgetWithText(ElevatedButton, 'Submit to Codeforces');
    expect(empty, findsOneWidget);
    expect(tester.widget<ElevatedButton>(empty).onPressed, isNull);
    expect(find.textContaining('Write your solution above'), findsOneWidget);

    // Code in the editor: submit is live, and claiming stays reachable for
    // anyone who solved it on the Codeforces site directly.
    await pumpBar(hasCode: true);
    final ready = find.widgetWithText(ElevatedButton, 'Submit to Codeforces');
    expect(tester.widget<ElevatedButton>(ready).onPressed, isNotNull);
    expect(find.textContaining('Claim'), findsOneWidget);

    // Waiting for the verdict: a bar that moves, and a way out of it.
    await pumpBar(hasCode: true, sent: true, waiting: true, checks: 3);
    expect(find.textContaining('3 of $verdictChecks'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        closeTo(3 / verdictChecks, 0.001));
    expect(find.widgetWithText(TextButton, 'Stop'), findsOneWidget);

    // Submitted, poll over. The thing left to do is collect the verdict, so
    // that is the primary action now — not submitting the same code again.
    await pumpBar(hasCode: true, sent: true);
    expect(find.widgetWithText(ElevatedButton, 'Check verdict'), findsOneWidget);
    expect(find.text('Submit to Codeforces'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  /// `isToday` is false for two entirely different reasons: the server fell
  /// back because Codeforces was unreachable, or you opened a challenge from
  /// the archive on purpose. The banner only means the first one, and it was
  /// firing on both — so every archived challenge, forever, claimed Codeforces
  /// was down.
  testWidgets('an archived challenge does not claim Codeforces is down',
      (WidgetTester tester) async {
    const stale = 'Codeforces is unreachable';

    await _pumpAt(
      tester,
      DailyChallengeView(
        today: _archived(ageDays: 6, award: 32),
        solvers: const [],
        askedForToday: false,
      ),
      const Size(360, 2400),
    );
    expect(find.textContaining(stale), findsNothing);
    // The age and the decay are how an archived challenge says it is old.
    expect(find.textContaining('6 days ago'), findsOneWidget);

    // Asking for today and being handed something older is the real fallback,
    // and it still says so.
    await _pumpAt(
      tester,
      DailyChallengeView(
        today: _archived(ageDays: 6, award: 32),
        solvers: const [],
        askedForToday: true,
      ),
      const Size(360, 2400),
    );
    expect(find.textContaining(stale), findsOneWidget);
  });

  testWidgets('the Codeforces verification sheet fits a phone',
      (WidgetTester tester) async {
    const task = CodeforcesVerification(
      handle: 'a_very_long_codeforces_handle_indeed',
      codeforcesId: '1873/D',
      problemUrl: 'https://codeforces.com/problemset/problem/1873/D',
      submitUrl: 'https://codeforces.com/problemset/submit/1873/D',
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

  /// The archive is a new screen, so it gets the standard hostile-data pass:
  /// a title with nothing to break on, six-figure points, and a decayed award
  /// shown next to the struck-through original.
  testWidgets('a past challenge tile fits a phone', (WidgetTester tester) async {
    final entries = <String, TodayChallenge>{
      'decayed, unsolved': _archived(ageDays: 6, award: 15, bonus: 99999),
      'at the floor, solved': _archived(
        ageDays: 40,
        award: 10,
        bonus: 99999,
        solved: true,
      ),
      'no decay yet': _archived(ageDays: 1, award: 99999, bonus: 99999),
    };

    for (final entry in entries.entries) {
      for (final size in const [_phone, _narrow]) {
        await _pumpAt(
          tester,
          PastChallengeTile(entry: entry.value, onTap: () {}),
          size,
        );
        expect(tester.takeException(), isNull,
            reason: '${entry.key} at $size');
      }
    }
  });

  /// Code is the one thing in the app that must not wrap, so the block scrolls
  /// sideways instead. That is exactly the shape that overflows if it is wired
  /// up wrong, which is what this asserts.
  testWidgets('a code block fits a phone with an unbreakable line',
      (WidgetTester tester) async {
    final code = [
      '#include <bits/stdc++.h>',
      'int main(){',
      '  ${'x' * 400};',
      '  return 0;',
      '}',
    ].join('\n');

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(tester, CodeBlock(code: code, language: 'cpp'), size);
      expect(tester.takeException(), isNull, reason: 'code block at $size');
    }
  });

  testWidgets('the code editor and attachment chip fit a phone',
      (WidgetTester tester) async {
    for (final size in const [_phone, _narrow]) {
      await _pumpAt(
        tester,
        SingleChildScrollView(
          child: Column(
            children: [
              CodeComposer(
                initial: const CodeSubmission(
                  codeBody: 'print("hello")',
                  codeLanguage: 'python',
                  attachmentUrl: 'https://example.com/a.py',
                  attachmentName:
                      'solution_with_an_absurdly_long_filename_v12_final.py',
                ),
                onChanged: (_) {},
              ),
              const AttachmentChip(
                url: 'https://example.com/a.py',
                name: 'solution_with_an_absurdly_long_filename_v12_final.py',
              ),
            ],
          ),
        ),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'code editor at $size');
    }
  });

  /// The regression this guards was reported as "there is no code submit
  /// button". There was an editor, but it was collapsed behind a text link and
  /// the only thing that persisted what you typed was "Claim" — which refuses
  /// unless Codeforces already shows an accepted verdict.
  testWidgets('the code editor offers a save button once there is code',
      (WidgetTester tester) async {
    CodeSubmission? submitted;

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(
        tester,
        SingleChildScrollView(
          child: CodeComposer(
            // Without a per-size key the element — and so the text controller
            // — is reused across the two pumps, and the second iteration
            // starts with the first one's code already typed in.
            key: ValueKey('composer-$size'),
            startOpen: true,
            onChanged: (_) {},
            onSubmit: (value) async => submitted = value,
          ),
        ),
        size,
      );

      // Open, not hidden behind "Add code".
      expect(find.byType(TextField), findsOneWidget, reason: 'editor at $size');

      // "Save", not "Submit": this button writes the code to the attempt
      // and calls no judge. Labelling it "Submit code" next to a button that
      // submits to Codeforces made two different acts read as one.
      final button = find.widgetWithText(ElevatedButton, 'Save code');
      expect(button, findsOneWidget, reason: 'save button at $size');

      // Nothing typed yet: offering to submit an empty solution would only
      // produce a server error.
      expect(tester.widget<ElevatedButton>(button).onPressed, isNull,
          reason: 'empty editor at $size');

      await tester.enterText(find.byType(TextField), 'print(1)');
      await tester.pump();

      expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull,
          reason: 'typed editor at $size');

      await tester.tap(button);
      await tester.pump();

      expect(submitted?.codeBody, 'print(1)');
      expect(tester.takeException(), isNull, reason: 'submit at $size');
      submitted = null;
    }
  });

  /// The one that made "code submit is not working" true for a brand new
  /// account: the whole editor sat behind `if (!today.codeforcesVerified)`, so
  /// the first thing anyone saw on this screen was one sentence about
  /// Codeforces and no submit button anywhere. Verifying gates *claiming* —
  /// `PUT /challenges/{id}/submission` has never asked for it (D40).
  testWidgets('an unverified user still gets the code editor',
      (WidgetTester tester) async {
    Widget unverified() => DailyChallengeView(
          today: _archived(ageDays: 0, award: 50, verified: false),
          solvers: const [],
          onSubmissionChanged: (_) {},
          onSubmitCode: (_) async {},
        );

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(tester, unverified(), size);
      expect(tester.takeException(), isNull, reason: 'unverified at $size');
    }

    // Content checks get a tall viewport: the screen is a lazy ListView, so on
    // a 640px phone the editor is simply not built yet and a `findsNothing`
    // here would be about scrolling rather than about the fix.
    await _pumpAt(tester, unverified(), const Size(360, 2400));

    expect(find.byType(CodeComposer), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Save solution'), findsOneWidget);
    // ...and the screen still says why claiming is blocked, rather than
    // leaving the pinned "Verify Codeforces handle" button unexplained.
    expect(find.textContaining('verify which account is yours'), findsOneWidget);
  });

  /// The editor comes before the rules. It used to come after a three-step
  /// explainer and a warning panel, which put the submit button a screen and a
  /// half below the fold on a phone — the reason it read as missing.
  testWidgets('the solution editor sits above the claim rules',
      (WidgetTester tester) async {
    await _pumpAt(
      tester,
      DailyChallengeView(
        today: _archived(ageDays: 0, award: 50),
        solvers: const [],
        onSubmissionChanged: (_) {},
        onSubmitCode: (_) async {},
      ),
      // Tall, because the screen is a lazy ListView: on a 640px phone the
      // rules simply are not built yet and this would compare against nothing.
      const Size(360, 2400),
    );

    final editor = tester.getTopLeft(find.byType(CodeComposer)).dy;
    final rules = tester.getTopLeft(find.text('How claiming works')).dy;
    expect(editor, lessThan(rules));
  });

  /// The pinned action bar reserves its own space instead of being drawn over
  /// the body. As a `bottomSheet` it overlaid the list, which is why the screen
  /// carried 140px of guessed bottom padding and still covered the last row
  /// whenever the bar wrapped.
  testWidgets('the pinned claim bar does not overlap the content',
      (WidgetTester tester) async {
    await _pumpScreen(
      tester,
      Scaffold(
        body: DailyChallengeView(
          today: _archived(ageDays: 0, award: 50),
          solvers: const [],
        ),
        bottomNavigationBar: ChallengeActionBar(
          today: _archived(ageDays: 0, award: 50),
          onClaim: () {},
          onVerify: () {},
          onOpenProblem: () {},
        ),
      ),
      _narrow,
    );

    expect(tester.takeException(), isNull);
    final barTop = tester.getTopLeft(find.byType(ChallengeActionBar)).dy;
    final listBottom = tester.getBottomLeft(find.byType(ListView)).dy;
    expect(listBottom, lessThanOrEqualTo(barTop),
        reason: 'the list must end where the bar begins, not under it');
  });

  /// Being offline used to be a dead end: an error page with a **Try again**
  /// button, so a phone that lost signal for four seconds needed a tap to come
  /// back. `offline` is the one failure that fixes itself, so it is drawn as a
  /// spinner that retries on its own (decisions.md D46).
  testWidgets('an offline failure retries itself instead of asking',
      (WidgetTester tester) async {
    var attempts = 0;

    await _pumpAt(
      tester,
      ErrorState(
        message: 'Could not reach the server.',
        offline: true,
        onRetry: () => attempts++,
      ),
      _phone,
    );

    // A spinner, not an error page — and no button to hunt for.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Waiting for a connection…'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsNothing);

    await tester.pump(ReconnectingState.gap);
    expect(attempts, 1, reason: 'it retries without being asked');

    // ...but not forever. design-system.md's rule is that nothing repeats
    // endlessly, and after the cap the button genuinely means something.
    for (var i = 1; i < ReconnectingState.maxAttempts; i++) {
      await tester.pump(ReconnectingState.gap);
    }
    expect(attempts, ReconnectingState.maxAttempts);

    await tester.pump();
    expect(find.text('Still offline'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Nothing is left ticking — a pending Timer fails a testWidgets body.
    await tester.pump(ReconnectingState.gap * 3);
    expect(attempts, ReconnectingState.maxAttempts);
  });

  testWidgets('a server refusal is still an error, not a spinner',
      (WidgetTester tester) async {
    // A 403 will still be a 403 in ten seconds. Only `offline` is worth
    // waiting through, so everything else keeps the message and the button.
    await _pumpAt(
      tester,
      ErrorState(message: 'You are not allowed to do that.', onRetry: () {}),
      _phone,
    );

    expect(find.text('You are not allowed to do that.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the answer composer keeps its editor collapsed',
      (WidgetTester tester) async {
    // The mirror of the test above: prose is the common case there, and an
    // always-open code pane would push the text field off a phone screen.
    await _pumpAt(
      tester,
      SingleChildScrollView(child: CodeComposer(onChanged: (_) {})),
      _phone,
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.widgetWithText(ElevatedButton, 'Save solution'), findsNothing);
  });

  /// An archived challenge renders through the same view as today's, with the
  /// decay note and a stored solution added — both new, both able to overflow.
  testWidgets('an archived challenge with a saved solution fits a phone',
      (WidgetTester tester) async {
    final entry = _archived(ageDays: 9, award: 10, bonus: 99999, solved: true);

    for (final size in const [_phone, _narrow]) {
      await _pumpAt(
        tester,
        DailyChallengeView(today: entry, solvers: const []),
        size,
      );
      expect(tester.takeException(), isNull, reason: 'archived at $size');
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
