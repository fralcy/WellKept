import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'data_manager.dart';

/// Stores photo bytes under a generated id in DataManager's photo lazy box;
/// records (e.g. `TrackedItem.photoId`) keep only that id. Same code path
/// on mobile and web — no file system involved.
///
/// Not wired to any UI yet: picking/capturing photos (image_picker) comes
/// in a later milestone. Display side: `FutureBuilder` over [load] +
/// `Image.memory`.
class PhotoStorageService {
  PhotoStorageService({DataManager? dataManager})
    : _dataManager = dataManager ?? DataManager();

  final DataManager _dataManager;

  /// Saves [bytes] and returns the new photo id.
  Future<String> save(Uint8List bytes) async {
    final id = const Uuid().v4();
    await _dataManager.savePhotoBytes(id, bytes);
    return id;
  }

  Future<Uint8List?> load(String id) => _dataManager.getPhotoBytes(id);

  Future<void> delete(String id) => _dataManager.deletePhotoBytes(id);
}
