import 'dart:io';
import 'dart:typed_data';

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

  /// Uploads raw bytes and returns the storage path.
  ///
  /// The image path goes through [uploadImage] and a `File`; code attachments
  /// cannot, because `file_picker` on the web has no filesystem to hand back —
  /// only bytes. This works on every platform the app builds for.
  Future<String> uploadBytes({
    required String bucketName,
    required Uint8List bytes,
    required String filePath,
    String? contentType,
  }) async {
    await _client.storage
        .from(bucketName)
        .uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
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
