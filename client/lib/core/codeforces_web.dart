import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'app_colors.dart';
import 'motion.dart';
import 'open_link.dart';
import 'widgets/app_snack.dart';

/// Codeforces, hosted inside QuestBoard.
///
/// The Codeforces API is read-only. It has no method for submitting a solution
/// and does not expose problem statements either — only metadata and verdicts —
/// so "read the problem and submit it without leaving the app" cannot be built
/// on the API at all. The two remaining options are to ask people for their
/// Codeforces password and drive the site as them, or to host Codeforces' own
/// pages. This is the second one (decisions.md D43).
///
/// It never sees a Codeforces credential: the user signs in on Codeforces' real
/// login page and the session cookie lives in the platform WebView's own store.
/// Nothing is typed into a form of our making, and the submit button they press
/// is Codeforces'.
///
/// `webview_flutter` covers Android, iOS and macOS. Everywhere else — the Linux
/// and Windows desktop builds, and web — [openCodeforces] hands off to a real
/// browser instead, which is the old behaviour and still correct there.

/// How a Codeforces page ended up being opened.
///
/// The caller needs to know: coming back from [CodeforcesOpen.embedded] means
/// the user has finished with the page and it is worth re-checking the verdict,
/// while [CodeforcesOpen.browser] returns the instant the browser launches and
/// the user is still over there.
enum CodeforcesOpen { embedded, browser, failed }

/// True where a page can be hosted in-app rather than handed to a browser.
///
/// `defaultTargetPlatform` rather than `dart:io`'s `Platform`: importing
/// `dart:io` at all fails to compile for the web, and `flutter run -d chrome`
/// is one of the ways this project is run.
bool get canEmbedCodeforces {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
}

/// Opens [url] inside the app where that is possible, and in a browser where
/// it is not. Reports its own failures; the caller only reads the outcome.
///
/// [prefillCode] is pasted into Codeforces' source box once the page settles.
/// It is a convenience, not a bypass — the code is the user's own, the session
/// is theirs, and they still choose the language and press Submit themselves.
Future<CodeforcesOpen> openCodeforces(
  BuildContext context,
  String url, {
  String title = 'Codeforces',
  String? prefillCode,
}) async {
  if (!canEmbedCodeforces) {
    final failure = await openLink(url);
    if (failure != null) {
      if (context.mounted) showAppSnack(context, failure);
      return CodeforcesOpen.failed;
    }
    return CodeforcesOpen.browser;
  }

  await Navigator.push(
    context,
    appRoute((_) => CodeforcesWebView(
          url: url,
          title: title,
          prefillCode: prefillCode,
        )),
  );
  return CodeforcesOpen.embedded;
}

/// Codeforces' compiler labels, in preference order, for each language the
/// in-app editor offers.
///
/// Matched against the text of the options in Codeforces' own `programTypeId`
/// select rather than against their numeric ids: the ids change when they roll
/// a compiler, and a stale id would submit C++17 code as Python. First regex
/// that matches any option wins, which is why 64-bit GNU builds come first.
///
/// A language with no entry — Dart, TypeScript, Swift, SQL — is one Codeforces
/// does not accept. [submitToCodeforces] leaves the form for the user rather
/// than guessing, because guessing here means a wrong-language verdict.
const codeforcesCompilers = <String, List<String>>{
  'cpp': [r'gnu g\+\+2[03].*64', r'gnu g\+\+', r'clang\+\+', r'c\+\+'],
  'c': [r'gnu gcc', r'\bgcc\b'],
  'python': [r'python 3', r'pypy 3', r'\bpython\b'],
  'java': [r'java 2\d', r'\bjava\b'],
  'kotlin': [r'kotlin'],
  'csharp': [r'c#', r'\.net'],
  'javascript': [r'node\.?js', r'javascript'],
  'go': [r'\bgo\b'],
  'rust': [r'rust'],
  'php': [r'php'],
  'ruby': [r'ruby'],
};

/// What an auto-submit run did.
enum CodeforcesSubmit {
  /// Codeforces accepted the form and moved on to the status page.
  submitted,

  /// The page is loaded and filled, but we could not choose a language for the
  /// user — so they finish it themselves.
  needsUser,

  /// The page never got as far as a submit form: cancelled, offline, or the
  /// user closed it during sign-in.
  incomplete,
}

/// Opens Codeforces' submit form, fills it from the in-app editor, and submits.
///
/// This is the vjudge-shaped flow, minus the part where vjudge holds your
/// Codeforces password. The session is the one the user established themselves
/// in this WebView, so nothing of theirs is stored anywhere and the request is
/// made by them, from their own browser context.
///
/// Falls back to [CodeforcesSubmit.needsUser] rather than submitting whenever
/// anything is uncertain — no matching compiler, no form, an unexpected page.
Future<CodeforcesSubmit> submitToCodeforces(
  BuildContext context, {
  required String url,
  required String code,
  String? language,
  String title = 'Submit',
}) async {
  if (!canEmbedCodeforces) {
    await openCodeforces(context, url, title: title, prefillCode: code);
    return CodeforcesSubmit.incomplete;
  }

  final outcome = await Navigator.push<CodeforcesSubmit>(
    context,
    appRoute((_) => CodeforcesWebView(
          url: url,
          title: title,
          prefillCode: code,
          autoSubmitLanguage: language,
        )),
  );
  return outcome ?? CodeforcesSubmit.incomplete;
}

/// One Codeforces page, in a QuestBoard frame.
class CodeforcesWebView extends StatefulWidget {
  const CodeforcesWebView({
    super.key,
    required this.url,
    this.title = 'Codeforces',
    this.prefillCode,
    this.autoSubmitLanguage,
  });

  final String url;
  final String title;

  /// Pasted into the submit form's source box when the page has loaded. Null
  /// on a statement page, which has no form to fill.
  final String? prefillCode;

  /// When set, the form is submitted as well as filled, choosing the Codeforces
  /// compiler that matches this language key. Null means fill only.
  final String? autoSubmitLanguage;

  @override
  State<CodeforcesWebView> createState() => _CodeforcesWebViewState();
}

class _CodeforcesWebViewState extends State<CodeforcesWebView> {
  late final WebViewController _controller;

  int _progress = 0;
  String? _error;

  /// Only ever attempted once. Codeforces fires `onPageFinished` again for
  /// in-page navigations, and re-pasting over something the user has since
  /// edited would be worse than not pasting at all.
  bool _prefillTried = false;

  /// Set while the form is being filled and posted, so the page underneath is
  /// covered rather than flickering through a submit the user never watched.
  bool _submitting = false;

  /// Codeforces bounces an unauthenticated submit link to `/enter`, so the form
  /// usually only appears on the *second* page load. Once a solution has gone
  /// through, every further load is the user browsing and is left alone.
  bool _submitted = false;

  /// How many times the form has been auto-filled and posted.
  ///
  /// Hard-capped, and the cap is the point. Codeforces re-renders the submit
  /// page with an error message when it rejects a post — "you have submitted
  /// exactly the same code before" is the common one — which fires
  /// `onPageFinished` again. Without a bound, that is an unbounded loop
  /// hammering their submit endpoint on the user's own account.
  int _submitAttempts = 0;

  /// One retry, which covers exactly one real case: the first load was the
  /// sign-in page and the form only appeared after the user signed in.
  static const _maxSubmitAttempts = 2;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onPageFinished: (url) {
          if (mounted) setState(() => _progress = 100);
          if (_submitted) return;
          // Landing on the status list is Codeforces confirming the post — the
          // submit form redirects there and nothing else does.
          if (_looksLikeSubmitted(url)) {
            _finish(CodeforcesSubmit.submitted);
            return;
          }
          if (widget.autoSubmitLanguage != null) {
            _fillAndSubmit();
          } else {
            _prefill();
          }
        },
        onUrlChange: (change) {
          final url = change.url;
          if (_submitted || url == null) return;
          if (_looksLikeSubmitted(url)) _finish(CodeforcesSubmit.submitted);
        },
        onWebResourceError: (error) {
          // Only when we are certain the *page* failed. `isForMainFrame` is
          // nullable and is not populated on every platform, and a sub-resource
          // failure — an ad frame, a font — is not the page failing. Blanking a
          // perfectly readable statement over one would be its own bug, so
          // anything short of a definite yes is left alone.
          if (error.isForMainFrame != true) return;
          if (mounted) setState(() => _error = error.description);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Best effort. Codeforces' submit form has changed shape before and will
  /// again, so this reports whether it actually landed rather than assuming,
  /// and the code is on the clipboard either way.
  Future<void> _prefill() async {
    final code = widget.prefillCode;
    if (code == null || code.isEmpty || _prefillTried) return;
    _prefillTried = true;

    await Clipboard.setData(ClipboardData(text: code));

    Object? filled;
    try {
      filled = await _controller.runJavaScriptReturningResult('''
        (function (source) {
          var box = document.getElementById('sourceCodeTextarea') ||
                    document.querySelector('textarea[name="source"]');
          if (!box) return false;
          box.value = source;
          box.dispatchEvent(new Event('input', { bubbles: true }));
          box.dispatchEvent(new Event('change', { bubbles: true }));
          return true;
        })(${jsonStringLiteral(code)});
      ''');
    } catch (_) {
      filled = false;
    }

    if (!mounted) return;
    final ok = filled == true || filled == 'true' || filled == 1;
    showAppSnack(
      context,
      ok
          ? 'Your code is in the form. Pick the language, then Submit.'
          : 'Your code is on the clipboard — paste it into the form.',
      tone: ok ? SnackTone.success : SnackTone.neutral,
    );
  }

  static bool _looksLikeSubmitted(String url) =>
      url.contains('/submissions/') || url.contains('problemset/status');

  void _finish(CodeforcesSubmit outcome) {
    if (_submitted || !mounted) return;
    _submitted = true;
    Navigator.of(context).pop(outcome);
  }

  /// Fills Codeforces' own form and posts it.
  ///
  /// Bails to [CodeforcesSubmit.needsUser] rather than guessing whenever the
  /// page is not what we expect — no form (the sign-in page, for one) or no
  /// compiler matching the language the code was written in. Submitting C++ as
  /// Python would earn a compile error on the user's public record, which is a
  /// far worse outcome than one extra tap.
  Future<void> _fillAndSubmit() async {
    final code = widget.prefillCode ?? '';
    final patterns = codeforcesCompilers[widget.autoSubmitLanguage] ?? const [];
    if (code.isEmpty || patterns.isEmpty) {
      await _prefill();
      return;
    }
    if (_submitAttempts >= _maxSubmitAttempts) {
      // Codeforces bounced it and re-rendered the form. Whatever it objects to,
      // posting the same thing again will not fix it — hand the page over.
      //
      // Clearing _submitting matters: the previous attempt returned 'ok' and so
      // left the overlay up waiting for a redirect that never came. Without
      // this the user is left staring at "Submitting to Codeforces…" over a
      // page that is actually asking them something.
      if (mounted) setState(() => _submitting = false);
      await _prefill();
      return;
    }
    _submitAttempts++;

    if (mounted) setState(() => _submitting = true);
    await Clipboard.setData(ClipboardData(text: code));

    final script = '''
      (function (source, patterns) {
        var box = document.getElementById('sourceCodeTextarea') ||
                  document.querySelector('textarea[name="source"]');
        if (!box) return 'noform';
        box.value = source;
        box.dispatchEvent(new Event('input', { bubbles: true }));
        box.dispatchEvent(new Event('change', { bubbles: true }));

        var select = document.querySelector('select[name="programTypeId"]');
        if (!select) return 'nolang';

        var chosen = -1;
        for (var p = 0; p < patterns.length && chosen < 0; p++) {
          var rx = new RegExp(patterns[p], 'i');
          for (var o = 0; o < select.options.length; o++) {
            if (rx.test(select.options[o].text)) { chosen = o; break; }
          }
        }
        if (chosen < 0) return 'nolang';

        select.selectedIndex = chosen;
        select.dispatchEvent(new Event('change', { bubbles: true }));

        var form = box.form || document.querySelector('form[action*="submit"]');
        if (!form) return 'nolang';

        // Click Codeforces' own control rather than calling form.submit():
        // submit() bypasses the page's submit handlers, and those are what
        // populate their anti-automation hidden fields and run their checks.
        // Falling back to submit() only if there is no button to press.
        var go = form.querySelector('input[type=submit], button[type=submit]');
        if (go) { go.click(); } else { form.submit(); }
        return 'ok';
      })(${jsonStringLiteral(code)},
         ${jsonStringLiteral(patterns.join('|||'))}.split('|||'));
    ''';

    Object? result;
    try {
      result = await _controller.runJavaScriptReturningResult(script);
    } catch (_) {
      result = 'noform';
    }

    final answer = _unwrap(result);
    if (!mounted) return;

    // The redirect that follows is what confirms it; onUrlChange finishes.
    if (answer == 'ok') return;

    setState(() => _submitting = false);

    if (answer == 'noform') {
      // Almost always the sign-in page. Saying so beats a silent nothing.
      showAppSnack(
        context,
        'Sign in to Codeforces here, and your solution goes in automatically.',
        tone: SnackTone.neutral,
      );
      return;
    }

    showAppSnack(
      context,
      'Your code is in the form — Codeforces has no compiler matching that '
      'language, so pick one and press Submit.',
      tone: SnackTone.neutral,
    );
  }

  /// Android hands JavaScript results back JSON-encoded; iOS does not.
  static String _unwrap(Object? value) {
    final text = (value ?? '').toString();
    if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
      return text.substring(1, text.length - 1);
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    // Back navigates *within* Codeforces before it leaves. Signing in bounces
    // through two or three pages, so a back gesture that closed the whole
    // WebView would throw away the login the user just completed. Closing is
    // the explicit ✕ instead.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // Captured before the await: this closure runs after one, and reaching
        // through `context` on the far side is what the lint is about.
        final navigator = Navigator.of(context);
        if (await _controller.canGoBack()) {
          await _controller.goBack();
          return;
        }
        if (mounted) {
          navigator.pop(widget.autoSubmitLanguage == null
              ? null
              : CodeforcesSubmit.needsUser);
        }
      },
      child: _scaffold(context),
    );
  }

  Widget _scaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.pop(
              context,
              widget.autoSubmitLanguage == null
                  ? null
                  : CodeforcesSubmit.needsUser),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary)),
            // Says out loud whose site this is. An embedded browser that does
            // not is one a user could mistake for our own login form.
            const Text('codeforces.com',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: () {
              setState(() => _error = null);
              _controller.reload();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Open in browser',
            onPressed: () async {
              final failure = await openLink(widget.url);
              if (failure != null && context.mounted) {
                showAppSnack(context, failure);
              }
            },
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
        bottom: _progress >= 100
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 3,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primaryTint,
                ),
              ),
      ),
      body: Stack(
        children: [
          if (_error != null)
            _failure()
          else
            WebViewWidget(controller: _controller),
          if (_submitting) _posting(),
        ],
      ),
    );
  }

  /// Covers the form while it is being filled and posted. Without it the user
  /// watches a page they did not open flicker through a submit they did not
  /// type, which reads as the app acting behind their back.
  Widget _posting() {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 18),
              Text('Submitting to Codeforces…',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _failure() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 44, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Could not load Codeforces.\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _controller.reload();
              },
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quotes [value] as a JavaScript string literal.
///
/// Source code is exactly the payload that breaks naive quoting — it is full of
/// quotes, backslashes and newlines — and this string is concatenated into a
/// script, so getting it wrong is an injection into our own WebView. JSON
/// string syntax is a subset of JavaScript's, so encoding it as JSON is both
/// correct and complete.
String jsonStringLiteral(String value) {
  final buffer = StringBuffer('"');
  for (final rune in value.runes) {
    switch (rune) {
      case 0x22:
        buffer.write(r'\"');
      case 0x5C:
        buffer.write(r'\\');
      case 0x0A:
        buffer.write(r'\n');
      case 0x0D:
        buffer.write(r'\r');
      case 0x09:
        buffer.write(r'\t');
      // U+2028 and U+2029 are line terminators in JavaScript but not in JSON,
      // so a source file containing either would end the literal early.
      case 0x2028:
        buffer.write(r' ');
      case 0x2029:
        buffer.write(r' ');
      default:
        if (rune < 0x20) {
          buffer.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
        } else {
          buffer.writeCharCode(rune);
        }
    }
  }
  return (buffer..write('"')).toString();
}
