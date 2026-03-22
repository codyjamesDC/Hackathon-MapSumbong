import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class StorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucket = 'photos';

  /// Pick an image from [source], upload to Supabase storage,
  /// and return the public URL. Returns null if cancelled or failed.
  static Future<String?> pickAndUpload({
    required ImageSource source,
    required String uploaderId,
  }) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (picked == null) return null; // user cancelled

      return await uploadFile(
        file: File(picked.path),
        uploaderId: uploaderId,
      );
    } catch (e) {
      debugPrint('StorageService.pickAndUpload error: $e');
      return null;
    }
  }

  /// Upload an existing [File] and return its public URL.
  static Future<String?> uploadFile({
    required File file,
    required String uploaderId,
  }) async {
    try {
      // Build a unique file path: uploaderId/timestamp.ext
      final ext = file.path.split('.').last.toLowerCase();
      final safeId = uploaderId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName =
          '$safeId/${DateTime.now().millisecondsSinceEpoch}.$ext';

      final bytes = await file.readAsBytes();

      await _supabase.storage.from(_bucket).uploadBinary(
            fileName,
            bytes,
            fileOptions: FileOptions(
              contentType: 'image/$ext',
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final publicUrl =
          _supabase.storage.from(_bucket).getPublicUrl(fileName);

      debugPrint('StorageService: uploaded → $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('StorageService.uploadFile error: $e');
      return null;
    }
  }
}