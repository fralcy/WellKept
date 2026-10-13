import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

/// Thin wrapper over `image_picker` — provided through Provider so widget
/// tests can swap in a fake instead of the platform picker.
class PhotoPickerService {
  const PhotoPickerService();

  /// Longest edge photos are scaled down to before saving: plenty for a
  /// receipt or a part number, and keeps each stored photo a few hundred KB
  /// rather than several MB.
  static const double maxDimension = 1600;

  /// Returns the picked image's bytes, or null if the user cancelled.
  Future<Uint8List?> pick(PhotoSource source) async {
    final file = await ImagePicker().pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: maxDimension,
      maxHeight: maxDimension,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }
}
