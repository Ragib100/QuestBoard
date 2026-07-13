import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseServices {
  SupabaseServices._();

  static final SupabaseServices instance = SupabaseServices._();

  final SupabaseClient _client = Supabase.instance.client;

  /// Uploads a file and returns its storage path.
  Future<String> uploadImage({
    required String bucketName,
    required File imageFile,
    required String filePath,
  }) async {
    await _client.storage
        .from(bucketName)
        .upload(
          filePath,
          imageFile,
          fileOptions: const FileOptions(upsert: true),
        );

    return filePath;
  }

  /// Deletes a file from storage.
  Future<void> deleteImage({
    required String bucketName,
    required String filePath,
  }) async {
    await _client.storage.from(bucketName).remove([filePath]);
  }

  /// Returns the public URL of a file.
  String getPublicUrl({required String bucketName, required String filePath}) {
    return _client.storage.from(bucketName).getPublicUrl(filePath);
  }
}
