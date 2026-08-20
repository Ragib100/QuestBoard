import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_services.dart';

/// A file the user picked and we uploaded.
class UploadedFile {
  const UploadedFile({required this.url, required this.name});

  final String url;
  final String name;
}

/// Thrown with a sentence that is safe to show the user.
class AttachmentException implements Exception {
  AttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Picking a source file and putting it in Storage.
///
/// The file goes straight from the device to the public `submissions` bucket —
/// FastAPI never sees the bytes, exactly as avatars already work. The API is
/// only ever told the resulting URL.
class AttachmentService {
  AttachmentService._();

  static final AttachmentService instance = AttachmentService._();

  static const bucket = 'submissions';

  /// Big enough for any source file or a small archive of one, small enough
  /// that a mistaken video upload fails immediately instead of after a minute
  /// on a phone connection.
  static const maxBytes = 5 * 1024 * 1024;

  /// Source files and the archives people bundle them in. Images are left out
  /// deliberately: answers already have their own image field.
  static const allowedExtensions = [
    'c', 'h', 'cpp', 'cc', 'hpp', 'cs', 'java', 'py', 'js', 'ts', 'dart',
    'go', 'rs', 'kt', 'swift', 'php', 'rb', 'sql', 'sh', 'txt', 'md',
    'json', 'yaml', 'yml', 'csv', 'pdf', 'zip',
  ];

  /// Opens the picker, uploads what was chosen, and returns its public URL.
  ///
  /// Returns null when the user dismissed the picker — that is a normal
  /// outcome, not an error, so it must not surface as one.
  Future<UploadedFile?> pickAndUpload() async {
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
    } catch (_) {
      throw AttachmentException('Could not open the file picker.');
    }

    if (file == null) return null;

    final Uint8List bytes;
    try {
      // Works the same on the web, where there is no path to read back from —
      // only the bytes the picker already holds.
      bytes = await file.readAsBytes();
    } catch (_) {
      throw AttachmentException('Could not read that file.');
    }

    if (bytes.length > maxBytes) {
      throw AttachmentException(
        'That file is ${(bytes.length / (1024 * 1024)).toStringAsFixed(1)}MB. '
        'The limit is ${maxBytes ~/ (1024 * 1024)}MB.',
      );
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw AttachmentException('Your session has expired. Please sign in again.');
    }

    // Namespaced by user and stamped with the clock so re-uploading a file
    // with the same name never overwrites someone else's submission.
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '$userId/$stamp-$safeName';

    try {
      await SupabaseServices.instance.uploadBytes(
        bucketName: bucket,
        bytes: bytes,
        filePath: path,
      );
    } on StorageException catch (e) {
      // Storage says exactly what went wrong — most usefully that the
      // `submissions` bucket does not exist yet (docs/setup.md step 11).
      // Swallowing that into "check your connection" sends whoever is setting
      // the project up looking in the wrong place entirely.
      throw AttachmentException('Upload failed: ${e.message}');
    } catch (_) {
      throw AttachmentException(
        'Upload failed. Check your connection and try again.',
      );
    }

    return UploadedFile(
      url: SupabaseServices.instance
          .getPublicUrl(bucketName: bucket, filePath: path),
      name: file.name,
    );
  }
}
