import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

abstract class ImageService {
  /// Picks an image from camera, saves it to app documents and returns the file path or null
  Future<String?> pickImageFromCamera();

  /// Picks an image from gallery, saves it to app documents and returns the file path or null
  Future<String?> pickImageFromGallery();

  /// Saves an existing [XFile] into app documents and returns the saved file path
  Future<String> saveXFile(XFile file);

  /// Lists saved image file paths in the app document directory
  Future<List<String>> listSavedImages();

  /// Deletes the given image file path. Returns true if deleted.
  Future<bool> deleteImage(String path);
}

class ImageServiceImpl implements ImageService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  @override
  Future<String?> pickImageFromCamera() async {
    final xfile =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (xfile == null) return null;
    return await saveXFile(xfile);
  }

  @override
  Future<String?> pickImageFromGallery() async {
    final xfile =
        await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (xfile == null) return null;
    return await saveXFile(xfile);
  }

  @override
  Future<String> saveXFile(XFile file) async {
    final dir = await getApplicationDocumentsDirectory();
    final ext = file.path.split('.').last;
    final fileName = '${_uuid.v4()}.$ext';
    final savedPath = '${dir.path}/$fileName';

    final savedFile = await File(file.path).copy(savedPath);
    return savedFile.path;
  }

  @override
  Future<List<String>> listSavedImages() async {
    final dir = await getApplicationDocumentsDirectory();
    final list = <String>[];
    try {
      final files = Directory(dir.path).listSync();
      for (final f in files) {
        if (f is File) {
          final ext = f.path.split('.').last.toLowerCase();
          if (['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext)) {
            list.add(f.path);
          }
        }
      }
    } catch (_) {}
    return list;
  }

  @override
  Future<bool> deleteImage(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
    } catch (_) {}
    return false;
  }
}
