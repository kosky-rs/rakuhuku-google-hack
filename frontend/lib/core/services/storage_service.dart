import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Storage service provider
final storageServiceProvider = Provider((ref) => StorageService());

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload clothing image to Firebase Storage
  ///
  /// Returns the download URL of the uploaded image
  /// Throws [FirebaseException] if upload fails
  Future<String> uploadClothingImage(String localPath, String userId) async {
    final file = File(localPath);

    // Generate unique filename: timestamp_random.jpg
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    final fileName = '${timestamp}_$random.jpg';

    // Storage path: closet_images/{userId}/{fileName}
    final storagePath = 'closet_images/$userId/$fileName';
    final ref = _storage.ref().child(storagePath);

    // Upload file
    final uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    // Wait for upload to complete
    final snapshot = await uploadTask;

    // Get download URL
    final downloadUrl = await snapshot.ref.getDownloadURL();

    return downloadUrl;
  }

  /// Delete image from Firebase Storage
  ///
  /// Returns true if deletion was successful
  Future<bool> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
      return true;
    } on FirebaseException catch (e) {
      // Log error but don't throw
      print('[StorageService] Failed to delete image: ${e.message}');
      return false;
    }
  }
}
