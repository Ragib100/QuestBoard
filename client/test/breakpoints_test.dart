import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client/app/intro.dart';
import 'package:client/core/breakpoints.dart';

void main() {
  test('isWideLayout is the documented 900px', () {
    // CLAUDE.md states the convention as `isWeb` (`width > 900`). If this
    // number moves, that line moves with it.
    expect(wideLayoutWidth, 900);
  });

  /// The bug this guards, and it was live: `dashboard.dart` used `> 960` while
  /// every other screen used `> 900`. In a window between the two the shell
  /// drew the phone layout — bottom nav, no sidebar, `embedded: true` — while
  /// the tab inside it decided it was on a desktop and drew its wide layout.
  ///
  /// A duplicated threshold is the only way for two screens to disagree, so
  /// the rule is that there is exactly one.
  test('no screen hardcodes its own width breakpoint', () {
    final offenders = <String>[];
    final pattern = RegExp(r'size\.width\s*[><]=?\s*\d');

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('core/breakpoints.dart')) continue;

      for (final (i, line) in entity.readAsLinesSync().indexed) {
        if (pattern.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'use isWideLayout(context) from core/breakpoints.dart');
  });

  testWidgets('the landing page section band reaches both window edges',
      (tester) async {
    // It used to sit inside the page's 1200px cap, so on a wide screen the
    // stripe stopped short of each edge and read as a misaligned block.
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: Intro()));
    await tester.pump();

    final bands = find.byType(ColoredBox).evaluate().map((e) => e.renderObject).whereType<RenderBox>().where((b) => b.hasSize && b.size.height > 100);

    expect(bands, isNotEmpty, reason: 'the highlights band should be rendered');
    for (final band in bands) {
      expect(band.localToGlobal(Offset.zero).dx, 0);
      expect(band.size.width, 1400);
    }
  });
}
