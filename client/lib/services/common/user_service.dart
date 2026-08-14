import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../api/api_client.dart';
import 'supabase_services.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String get _apiUrl => dotenv.get('API_URL').replaceFirst(RegExp(r'/$'), '');

  Future<void> createUser({
    required String username,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String codeforcesHandle,
    File? imageFile,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception("User is not authenticated.");
    }

    var imagePath = '';
    if (imageFile != null) {
      final extension = path.extension(imageFile.path);
      imagePath =
          "${user.id}/${DateTime.now().millisecondsSinceEpoch}$extension";
      await SupabaseServices.instance.uploadImage(
        bucketName: 'profile_image',
        imageFile: imageFile,
        filePath: imagePath,
      );
    }

    // Get access token
    final accessToken = _supabase.auth.currentSession?.accessToken;
    if (accessToken == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }

    final response = await http.post(
      Uri.parse("$_apiUrl/api/users"),
      headers: {
        "Authorization": "Bearer $accessToken",
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "username": username,
        "first_name": firstName,
        "last_name": lastName,
        "phone_number": phoneNumber,
        "codeforces_handle": codeforcesHandle,
        "image_url": imagePath,
      }),
    );

    if (response.statusCode != 201) {
      final body = jsonDecode(response.body);
      final detail = body is Map<String, dynamic> ? body['detail'] : null;
      throw Exception(detail ?? 'Failed to create your profile.');
    }
  }

  /// The signed-in user's own profile.
  ///
  /// Throws an [ApiException] with `isNotFound` when the account is verified
  /// but onboarding was never completed — the caller should route to
  /// ProfileCreate rather than treat it as an error.
  Future<Profile> me() async {
    final json = await ApiClient.instance.get('/users/me');
    return Profile.fromJson(json as Map<String, dynamic>);
  }

  Future<Profile> getProfile(String userId) async {
    final json = await ApiClient.instance.get('/users/$userId');
    return Profile.fromJson(json as Map<String, dynamic>);
  }

  Future<Profile> updateProfile({
    required String userId,
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? codeforcesHandle,
    String? imageUrl,
  }) async {
    final json = await ApiClient.instance.patch('/users/$userId', body: {
      if (username != null) 'username': username,
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (codeforcesHandle != null) 'codeforces_handle': codeforcesHandle,
      if (imageUrl != null) 'image_url': imageUrl,
    });
    return Profile.fromJson(json as Map<String, dynamic>);
  }

  Future<({int balance, List<PointEntry> entries})> points(String userId) async {
    final json =
        await ApiClient.instance.get('/users/$userId/points') as Map<String, dynamic>;
    return (
      balance: json['balance'] as int? ?? 0,
      entries: (json['transactions'] as List<dynamic>? ?? [])
          .map((e) => PointEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Uploads a new avatar and returns its storage path.
  Future<String> uploadAvatar(File imageFile) async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw ApiException('Your session has expired. Please sign in again.');
    }
    final extension = path.extension(imageFile.path);
    final filePath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}$extension';
    await SupabaseServices.instance.uploadImage(
      bucketName: 'profile_image',
      imageFile: imageFile,
      filePath: filePath,
    );
    return filePath;
  }

  /// Public URL for a stored avatar path, or null when there is none.
  String? avatarUrl(String storagePath) {
    if (storagePath.isEmpty) return null;
    return SupabaseServices.instance
        .getPublicUrl(bucketName: 'profile_image', filePath: storagePath);
  }
}
