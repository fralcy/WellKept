import 'dart:typed_data';

import '../../models/app_settings.dart';
import '../../models/maintenance_log.dart';
import '../../models/tracked_item.dart';

/// Everything a backup file carries: the records plus the bytes of every
/// photo they reference, keyed by photo id.
class BackupData {
  const BackupData({
    required this.items,
    required this.logs,
    required this.settings,
    required this.photos,
  });

  final List<TrackedItem> items;
  final List<MaintenanceLog> logs;
  final AppSettings settings;
  final Map<String, Uint8List> photos;
}
