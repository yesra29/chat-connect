import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class MediaService {
  late final FirebaseStorage _storage;
  final ImagePicker _picker = ImagePicker();
  bool _isInitialized = false;

  MediaService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _storage = FirebaseStorage.instance;
      // Set maximum upload and operation retry times
      _storage.setMaxUploadRetryTime(const Duration(seconds: 30));
      _storage.setMaxOperationRetryTime(const Duration(seconds: 30));
      _isInitialized = true;
      print("MediaService initialized successfully");
    } catch (e) {
      print("Error initializing MediaService: $e");
      _isInitialized = false;
      rethrow;
    }
  }

  Future<XFile?> getImageFromGallery() async {
    try {
      print("Attempting to pick image from gallery");
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      print("Image pick result: ${image?.path ?? 'null'}");
      return image;
    } catch (e) {
      print("Error picking image: $e");
      rethrow;
    }
  }

  Future<String> uploadMedia(File file, String storagePath) async {
    if (!_isInitialized) {
      print("MediaService not initialized, attempting to initialize...");
      await _initialize();
    }

    try {
      print("Starting media upload to Firebase Storage...");
      print("File path: ${file.path}");
      print("Storage path: $storagePath");

      // Check if file exists
      if (!await file.exists()) {
        throw Exception("File does not exist at path: ${file.path}");
      }

      // Get file size
      final fileSize = await file.length();
      print("File size: $fileSize bytes");

      // Create storage reference
      final storageRef = _storage.ref().child(storagePath);
      print("Storage reference created: $storagePath");

      // Start upload
      print("Starting upload...");
      final uploadTask = storageRef.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'uploadedBy': 'user',
            'timestamp': DateTime.now().toString(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print("Upload progress: ${progress.toStringAsFixed(2)}%");
      });

      // Wait for upload to complete
      final snapshot = await uploadTask;
      print("Upload completed successfully");

      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print("Download URL obtained: $downloadUrl");

      return downloadUrl;
    } on FirebaseException catch (e) {
      print("Firebase error during upload: ${e.code} - ${e.message}");
      print("Stack trace: ${e.stackTrace}");
      throw Exception("Failed to upload media: ${e.message}");
    } catch (e, stackTrace) {
      print("Error uploading media: $e");
      print("Stack trace: $stackTrace");
      throw Exception("Failed to upload media: $e");
    }
  }
}
