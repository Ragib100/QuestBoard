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

  String get _baseUrl =>
      dotenv.get('API_URL', fallback: '').replaceFirst(RegExp(r'/+$'), '');

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

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleaned = query?.map((k, v) => MapEntry(k, '$v'))
      ?..removeWhere((_, v) => v.isEmpty);
    return Uri.parse('$_baseUrl/api$path').replace(
      queryParameters: (cleaned == null || cleaned.isEmpty) ? null : cleaned,
    );
  }

  Future<dynamic> get(String path,
      {Map<String, dynamic>? query, bool auth = true}) async {
    return _send(() => http.get(_uri(path, query), headers: _headers(auth: auth)));
  }

  Future<dynamic> post(String path, {Object? body, bool auth = true}) async {
    return _send(() => http.post(
          _uri(path),
          headers: _headers(auth: auth),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send(() => http.patch(
          _uri(path),
          headers: _headers(),
          body: jsonEncode(body ?? const {}),
        ));
  }

  Future<dynamic> delete(String path) async {
    return _send(() => http.delete(_uri(path), headers: _headers()));
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(const Duration(seconds: 20));
    } on ApiException {
      rethrow;
    } catch (_) {
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
