import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucket = 'photos';

  /// Pick an image from [source] (camera or gallery), upload it to Supabase
  /// storage, and return the public URL. Returns null if the user cancels
  /// or if the upload fails.
  static Future<String?> pickAndUpload({
    required ImageSource source,
    required String uploaderId,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,   // compress to ~75% quality
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (picked == null) return null; // user cancelled

      return await uploadFile(
        file: File(picked.path),
        uploaderId: uploaderId,
      );
    } catch (e) {
      return null;
    }
  }

  /// Upload an existing [File] and return its public URL.
  static Future<String?> uploadFile({
    required File file,
    required String uploaderId,
  }) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final fileName =
          '$uploaderId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      await _supabase.storage.from(_bucket).upload(
            fileName,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final publicUrl =
          _supabase.storage.from(_bucket).getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      return null;
    }
  }
}