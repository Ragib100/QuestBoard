import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:client/core/code_format.dart';
import 'package:client/core/code_syntax.dart';
import 'package:client/core/widgets/code_composer.dart';
import 'package:client/models/code_submission.dart';

/// Every case here is code the way it actually arrives in the app: pasted with
/// its indentation flattened, or typed on a phone with none at all.
void main() {
  group('formatCode — brackets', () {
    test('C++ nests four spaces a level and keeps # in column 0', () {
      const source = '''
#include <bits/stdc++.h>
using namespace std;
int main() {
int n;
cin >> n;
if (n > 0) {
cout << n << endl;
}
return 0;
}''';
      expect(formatCode(source, 'cpp').code, '''
#include <bits/stdc++.h>
using namespace std;
int main() {
    int n;
    cin >> n;
    if (n > 0) {
        cout << n << endl;
    }
    return 0;
}''');
    });

    test('a closing brace lines up with the line that opened it', () {
      const source = 'void f() {\n  if (a) {\n  g();\n      }\n}';
      expect(formatCode(source, 'cpp').code,
          'void f() {\n    if (a) {\n        g();\n    }\n}');
    });

    test('} else { keeps both halves at the outer level', () {
      const source = 'if (a) {\nb();\n} else {\nc();\n}';
      expect(formatCode(source, 'java').code,
          'if (a) {\n    b();\n} else {\n    c();\n}');
    });

    test('switch puts case one level in and its body one deeper', () {
      const source =
          'switch (x) {\ncase 1:\nfoo();\nbreak;\ndefault:\nbar();\n}';
      expect(formatCode(source, 'cpp').code,
          'switch (x) {\n    case 1:\n        foo();\n        break;\n'
          '    default:\n        bar();\n}');
    });

    test('an unbraced if indents the statement under it — and only that one',
        () {
      const source = 'if (a)\nb();\nc();';
      expect(formatCode(source, 'c').code, 'if (a)\n    b();\nc();');
    });

    test('a brace on its own line stays with its statement', () {
      const source = 'if (a)\n{\nb();\n}';
      expect(formatCode(source, 'c').code, 'if (a)\n{\n    b();\n}');
    });

    test('Dart and JavaScript indent two spaces, Go uses tabs', () {
      expect(formatCode('void main() {\nprint(1);\n}', 'dart').code,
          'void main() {\n  print(1);\n}');
      expect(formatCode('function f() {\nreturn 1;\n}', 'javascript').code,
          'function f() {\n  return 1;\n}');
      expect(formatCode('func main() {\nfmt.Println(1)\n}', 'go').code,
          'func main() {\n\tfmt.Println(1)\n}');
    });

    test('PHP indents four and leaves the open tag alone', () {
      const source = '<?php\nfunction f() {\nreturn 1;\n}';
      expect(formatCode(source, 'php').code,
          '<?php\nfunction f() {\n    return 1;\n}');
    });

    test('a brace inside a string does not open a block', () {
      const source = 'void f() {\nprint("} not a brace {");\ng();\n}';
      expect(formatCode(source, 'dart').code,
          'void f() {\n  print("} not a brace {");\n  g();\n}');
    });

    test('a commented-out brace does not open a block', () {
      const source = 'void f() {\n// if (a) {\ng();\n}';
      expect(formatCode(source, 'cpp').code,
          'void f() {\n    // if (a) {\n    g();\n}');
    });

    test('wrapped arguments get one level, the closing paren none', () {
      const source = 'foo(\nbar,\nbaz\n);';
      expect(formatCode(source, 'dart').code, 'foo(\n  bar,\n  baz\n);');
    });

    test('already-formatted code reports no change', () {
      const source = 'void main() {\n  print(1);\n}';
      final result = formatCode(source, 'dart');
      expect(result.changed, isFalse);
      expect(result.code, source);
    });

    test('trailing whitespace and blank tail lines go away', () {
      final result = formatCode('int a;   \n\n\n', 'c');
      expect(result.code, 'int a;');
    });
  });

  group('formatCode — Python', () {
    test('normalises odd indent widths to four-space steps', () {
      const source = 'def f():\n  if x:\n        return 1\n  return 0';
      expect(formatCode(source, 'python').code,
          'def f():\n    if x:\n        return 1\n    return 0');
    });

    test('leaves a triple-quoted body exactly as written', () {
      const source = 'def f():\n  """Doc.\n     Indented on purpose.\n  """\n  return 1';
      expect(formatCode(source, 'python').code,
          'def f():\n    """Doc.\n     Indented on purpose.\n  """\n    return 1');
    });

    test('gives continuation lines inside brackets one extra level', () {
      const source = 'def f():\n  return foo(\n  a,\n  b,\n  )';
      expect(formatCode(source, 'python').code,
          'def f():\n    return foo(\n        a,\n        b,\n    )');
    });
  });

  group('formatCode — keyword languages', () {
    test('Ruby closes on end and indents two', () {
      const source = 'def f\nif x\nputs 1\nelse\nputs 2\nend\nend';
      expect(formatCode(source, 'ruby').code,
          'def f\n  if x\n    puts 1\n  else\n    puts 2\n  end\nend');
    });

    test('a Ruby one-liner with its own end is not a block', () {
      const source = 'def f\nputs 1 if x\nputs 2\nend';
      expect(formatCode(source, 'ruby').code,
          'def f\n  puts 1 if x\n  puts 2\nend');
    });

    test('Bash indents between then/fi and do/done', () {
      const source = 'for f in *; do\nif [ -f "\$f" ]; then\necho "\$f"\nfi\ndone';
      expect(formatCode(source, 'bash').code,
          'for f in *; do\n  if [ -f "\$f" ]; then\n    echo "\$f"\n  fi\ndone');
    });
  });

  test('plain text has no format to apply', () {
    expect(canFormatCode('text'), isFalse);
    final result = formatCode('   hello\n     world', 'text');
    expect(result.changed, isFalse);
    expect(result.code, '   hello\n     world');
  });

  group('indentAfterNewline', () {
    test('carries the current line down and adds a level after a brace', () {
      expect(indentAfterNewline('int main() {', 'cpp'), '    ');
      expect(indentAfterNewline('    int x = 1;', 'cpp'), '    ');
      expect(indentAfterNewline('    if (x) {', 'cpp'), '        ');
    });

    test('follows a Python colon and a bash then', () {
      expect(indentAfterNewline('def f():', 'python'), '    ');
      expect(indentAfterNewline('if [ -f x ]; then', 'bash'), '  ');
      expect(indentAfterNewline('  echo hi', 'bash'), '  ');
    });

    test('indents an unbraced if by one level', () {
      expect(indentAfterNewline('if (x)', 'c'), '    ');
    });

    test('keeps the indentation of a plain-text line without adding to it', () {
      expect(indentAfterNewline('   note {', 'text'), '   ');
    });

    test('a brace inside a string does not open a level', () {
      expect(indentAfterNewline('  print("{");', 'dart'), '  ');
    });
  });

  group('the editor', () {
    Future<TextField> pumpComposer(WidgetTester tester, String code) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CodeComposer(
              startOpen: true,
              initial: CodeSubmission(codeBody: code, codeLanguage: 'cpp'),
              onChanged: (_) {},
            ),
          ),
        ),
      ));
      return tester.widget<TextField>(find.byType(TextField));
    }

    testWidgets('Fix indent re-indents what is in the field', (tester) async {
      final field = await pumpComposer(tester, 'int main() {\nreturn 0;\n}');

      await tester.tap(find.text('Fix indent'));
      await tester.pump();

      expect(field.controller!.text, 'int main() {\n    return 0;\n}');
    });

    testWidgets('Indent shifts the selected lines, not the caret by a space',
        (tester) async {
      final field = await pumpComposer(tester, 'a;\nb;');
      field.controller!.selection =
          const TextSelection(baseOffset: 0, extentOffset: 5);

      await tester.tap(find.text('Indent'));
      await tester.pump();

      expect(field.controller!.text, '    a;\n    b;');
    });

    testWidgets('Tab indents instead of moving focus', (tester) async {
      final field = await pumpComposer(tester, 'a;');
      await tester.tap(find.byType(TextField));
      await tester.pump();
      field.controller!.selection = const TextSelection.collapsed(offset: 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(field.controller!.text, '    a;');
    });
  });

  group('highlighting', () {
    test('keywords, strings, numbers and comments are told apart', () {
      const source = 'int x = 42; // note\nchar* s = "hi";';
      final kinds = {
        for (final token in tokenizeCode(source, 'c'))
          source.substring(token.start, token.end): token.kind,
      };
      expect(kinds['int'], CodeTokenKind.type);
      expect(kinds['return'], isNull);
      expect(kinds['42'], CodeTokenKind.number);
      expect(kinds['// note'], CodeTokenKind.comment);
      expect(kinds['"hi"'], CodeTokenKind.string);
    });

    test('an unterminated string stops at the newline', () {
      const source = 'print("oops\nint x = 1;';
      final strings = tokenizeCode(source, 'cpp')
          .where((t) => t.kind == CodeTokenKind.string);
      expect(strings.single.end, source.indexOf('\n'));
    });

    test('SQL keywords match in either case', () {
      final kinds = {
        for (final token in tokenizeCode('SELECT * from t;', 'sql'))
          token.kind,
      };
      expect(kinds, contains(CodeTokenKind.keyword));
    });

    test('plain text is one span and no tokens', () {
      expect(tokenizeCode('just words', 'text'), isEmpty);
      expect(isHighlightable('text'), isFalse);
    });

    test('every line of the block gets a span, including empty ones', () {
      const source = 'int a;\n\nint b;';
      final spans = highlightCodeLines(source, 'c', const TextStyle());
      expect(spans.length, 3);
    });
  });
}
