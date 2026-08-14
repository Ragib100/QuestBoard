import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thrown for any non-2xx response. [message] is always safe to show a user:
/// it carries the API's `detail` string, never a raw exception.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// The caller is authenticated but has not completed onboarding yet.
  bool get isNotFound => statusCode == 404;

  /// Not enough points for the action.
  bool get isPaymentRequired => statusCode == 402;

  @override
  String toString() => message;
}

/// One place that knows how to reach the API: base URL, bearer token, JSON
/// decoding, and turning failures into [ApiException]s.
class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  /// Long enough for a cold Render dyno, short enough that a wrong `API_URL`
  /// surfaces as an error instead of a frozen screen.
  static const defaultTimeout = Duration(seconds: 10);

  /// For calls made while the user is staring at a blank screen — startup
  /// routing would rather guess quickly than block on an unreachable server.
  static const fastTimeout = Duration(seconds: 4);

  /// How long to wait for a candidate host to answer the reachability probe.
  static const _probeTimeout = Duration(seconds: 3);

  /// The candidate host that answered, cached for the process lifetime.
  String? _resolvedBase;
  Future<String>? _resolving;

  /// `API_URL` may hold several comma-separated candidates. A phone plugged in
  /// over USB reaches the dev machine at `localhost` (with `adb reverse`), an
  /// emulator at `10.0.2.2`, and a phone on the same Wi-Fi at the laptop's LAN
  /// address — which changes whenever the network does. Listing all three and
  /// letting the app find the live one removes the single most common cause of
  /// "cannot reach the server": an `API_URL` that was correct last week.
  List<String> get _candidates => dotenv
      .get('API_URL', fallback: '')
      .split(',')
      .map((s) => s.trim().replaceFirst(RegExp(r'/+$'), ''))
      .where((s) => s.isNotEmpty)
      .toList();

  /// Probes every candidate at once and keeps the first that answers. Falls
  /// back to the first candidate when none do, so the resulting failure is a
  /// normal "could not reach the server" rather than a malformed URL.
  Future<String> _baseUrl() async {
    final cached = _resolvedBase;
    if (cached != null) return cached;

    final inFlight = _resolving ??= _probe();
    final base = await inFlight;
    _resolvedBase = base;
    _resolving = null;
    return base;
  }

  Future<String> _probe() async {
    final candidates = _candidates;
    if (candidates.isEmpty) return '';
    if (candidates.length == 1) return candidates.first;

    final winner = Completer<String>();
    var pending = candidates.length;

    for (final base in candidates) {
      http
          .get(Uri.parse('$base/api/'))
          .timeout(_probeTimeout)
          .then((response) {
        if (response.statusCode == 200 && !winner.isCompleted) {
          winner.complete(base);
        }
      }).catchError((_) {
        // A candidate that is not listening is the expected case, not an error.
      }).whenComplete(() {
        if (--pending == 0 && !winner.isCompleted) {
          winner.complete(candidates.first);
        }
      });
    }

    return winner.future;
  }

  /// Forces the next request to probe again — called when a request fails at
  /// the network layer, so moving between Wi-Fi and USB recovers on retry
  /// instead of needing an app restart.
  void _invalidateBase() {
    _resolvedBase = null;
    _resolving = null;
  }

  Map<String, String> _headers({bool auth = true}) {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) {
        throw ApiException('Your session has expired. Please sign in again.');
      }
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Uri> _uri(String path, [Map<String, dynamic>? query]) async {
    final cleaned = query?.map((k, v) => MapEntry(k, '$v'))
      ?..removeWhere((_, v) => v.isEmpty);
    return Uri.parse('${await _baseUrl()}/api$path').replace(
      queryParameters: (cleaned == null || cleaned.isEmpty) ? null : cleaned,
    );
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
    Duration? timeout,
  }) async {
    return _send(
      () async => http.get(await _uri(path, query), headers: _headers(auth: auth)),
      timeout: timeout,
    );
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    return _send(() async => http.post(
          await _uri(path),
          headers: _headers(auth: auth),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send(() async => http.patch(
          await _uri(path),
          headers: _headers(),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<dynamic> delete(String path) async {
    return _send(() async => http.delete(await _uri(path), headers: _headers()));
  }

  Future<dynamic> _send(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    final http.Response response;
    try {
      response = await request().timeout(timeout ?? defaultTimeout);
    } on ApiException {
      rethrow;
    } catch (_) {
      // The chosen host stopped answering — the laptop's IP changed, or the
      // phone moved between Wi-Fi and USB. Re-probe on the next call so a
      // retry recovers without restarting the app.
      _invalidateBase();
      throw ApiException(
        'Could not reach the server. Check your connection and try again.',
      );
    }

    if (response.statusCode == 204 || response.body.isEmpty) return null;

    final dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'The server returned an unexpected response.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    throw ApiException(
      _detailOf(decoded) ?? 'Something went wrong. Please try again.',
      statusCode: response.statusCode,
    );
  }

  /// FastAPI returns `{"detail": "..."}`, but validation errors make `detail`
  /// a list of field objects — flatten both into one readable line.
  String? _detailOf(dynamic decoded) {
    if (decoded is! Map) return null;
    final detail = decoded['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) return '${first['msg']}';
    }
    return null;
  }
}
