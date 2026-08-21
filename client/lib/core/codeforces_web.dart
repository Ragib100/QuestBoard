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

/// One Codeforces page, in a QuestBoard frame.
class CodeforcesWebView extends StatefulWidget {
  const CodeforcesWebView({
    super.key,
    required this.url,
    this.title = 'Codeforces',
    this.prefillCode,
  });

  final String url;
  final String title;

  /// Pasted into the submit form's source box when the page has loaded. Null
  /// on a statement page, which has no form to fill.
  final String? prefillCode;

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

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) {
          if (mounted) setState(() => _progress = value);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _progress = 100);
          _prefill();
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
        if (mounted) navigator.pop();
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
          onPressed: () => Navigator.pop(context),
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
      body: _error != null ? _failure() : WebViewWidget(controller: _controller),
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
