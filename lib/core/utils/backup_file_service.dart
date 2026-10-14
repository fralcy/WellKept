import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saves/picks backup files via `file_picker`, which handles every
/// platform itself (a save dialog/share sheet on mobile, a download on
/// web). Provided through Provider so widget tests can use a fake.
class BackupFileService {
  const BackupFileService();

  /// Returns false if the user cancelled.
  Future<bool> save(String fileName, Uint8List bytes) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'application/zip',
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    return uri != null;
  }

  /// The picked file's bytes, or null if the user cancelled.
  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
    );
    return file?.readAsBytes();
  }
}
