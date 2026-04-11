import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload a profile picture for the current user
  static Future<String?> uploadProfilePicture(File imageFile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final ref = _storage.ref().child('profiles/${user.uid}/avatar.jpg');
      
      final uploadTask = await ref.putFile(
        imageFile, 
        SettableMetadata(contentType: 'image/jpeg')
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      // Also update the FirebaseAuth profile if needed
      await user.updatePhotoURL(downloadUrl);
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload profile picture: $e');
      return null;
    }
  }

  /// Upload any file to a specific path
  static Future<String?> uploadFile(String path, File file) async {
    try {
      final ref = _storage.ref().child(path);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Failed to upload file to $path: $e');
      return null;
    }
  }

  /// Delete a file from Firebase Storage
  static Future<bool> deleteFile(String path) async {
    try {
      await _storage.ref().child(path).delete();
      return true;
    } catch (e) {
      debugPrint('Failed to delete file at $path: $e');
      return false;
    }
  }
}
