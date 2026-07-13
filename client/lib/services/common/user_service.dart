import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_services.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final SupabaseClient _supabase = Supabase.instance.client;

  String get _apiUrl => dotenv.env['API_URL']!;

  Future<void> createUser({
    required String username,
    required String firstName,
    required String lastName,
    String? phoneNumber,
    required String codeforcesHandle,
    required File imageFile,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception("User is not authenticated.");
    }

    // Upload image first
    final extension = path.extension(imageFile.path);

    final imagePath =
        "${user.id}/${DateTime.now().millisecondsSinceEpoch}$extension";

    await SupabaseServices.instance.uploadImage(
      bucketName: "profile_image",
      imageFile: imageFile,
      filePath: imagePath,
    );

    // Get access token
    final accessToken = _supabase.auth.currentSession!.accessToken;

    // print("Access Token: $accessToken");
    // print("API URL: $_apiUrl");

    // Send request to backend
    // print(
    //   "Creating user with username: $username, firstName: $firstName, lastName: $lastName, phoneNumber: $phoneNumber, codeforcesHandle: $codeforcesHandle, imagePath: $imagePath",
    // );
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

    // print("Response status: ${response.statusCode}");
    // print("Response body: ${response.body}");

    if (response.statusCode != 201) {
      throw Exception(
        jsonDecode(response.body)["detail"] ?? "Failed to create user.",
      );
    }
  }
}
