import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../models/app_settings.dart';
import '../../models/maintenance_log.dart';
import '../../models/tracked_item.dart';
import '../models/backup_data.dart';

/// Why a file couldn't be read as a backup — mapped to a localized message
/// by the UI.
enum BackupError {
  /// Not a zip, or a zip without `wellkept.json`.
  notABackup,

  /// Written by a newer app version with a format this one doesn't know.
  newerVersion,

  /// A WellKept backup, but its contents don't parse.
  corrupt,
}

class BackupFormatException implements Exception {
  const BackupFormatException(this.error, [this.detail]);

  final BackupError error;
  final Object? detail;

  @override
  String toString() => 'BackupFormatException($error, $detail)';
}

/// Pure Dart (no file I/O): [BackupData] ⇄ zip bytes. The zip holds
/// `wellkept.json` (records + [schemaVersion]) and `photos/<photoId>`.
class BackupService {
  const BackupService();

  /// Bump when the JSON shape changes incompatibly; [decode] refuses
  /// anything newer than it knows.
  static const int schemaVersion = 1;

  static const String _dataFile = 'wellkept.json';
  static const String _photoDir = 'photos/';

  Uint8List encode(BackupData data, {DateTime? exportedAt}) {
    final json = {
      'schemaVersion': schemaVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toIso8601String(),
      'settings': _settingsToJson(data.settings),
      'items': [for (final item in data.items) _itemToJson(item)],
      'logs': [for (final log in data.logs) _logToJson(log)],
    };
    final archive = Archive()
      ..addFile(ArchiveFile.bytes(_dataFile, utf8.encode(jsonEncode(json))));
    for (final entry in data.photos.entries) {
      archive.addFile(ArchiveFile.bytes('$_photoDir${entry.key}', entry.value));
    }
    return ZipEncoder().encodeBytes(archive);
  }

  /// Throws [BackupFormatException] when [bytes] isn't a backup this app
  /// version can read.
  BackupData decode(Uint8List bytes) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw BackupFormatException(BackupError.notABackup, e);
    }
    final dataFile = archive.findFile(_dataFile);
    final dataBytes = dataFile?.readBytes();
    if (dataBytes == null) {
      throw const BackupFormatException(BackupError.notABackup);
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(dataBytes)) as Map<String, dynamic>;
    } catch (e) {
      throw BackupFormatException(BackupError.corrupt, e);
    }
    final version = json['schemaVersion'];
    if (version is! int) {
      throw const BackupFormatException(BackupError.corrupt);
    }
    if (version > schemaVersion) {
      throw BackupFormatException(BackupError.newerVersion, version);
    }

    try {
      final photos = <String, Uint8List>{};
      for (final file in archive.files) {
        if (!file.isFile || !file.name.startsWith(_photoDir)) continue;
        final id = file.name.substring(_photoDir.length);
        final content = file.readBytes();
        if (id.isNotEmpty && content != null) photos[id] = content;
      }
      return BackupData(
        settings: _settingsFromJson(json['settings'] as Map<String, dynamic>),
        items: [
          for (final item in json['items'] as List)
            _itemFromJson(item as Map<String, dynamic>),
        ],
        logs: [
          for (final log in json['logs'] as List)
            _logFromJson(log as Map<String, dynamic>),
        ],
        photos: photos,
      );
    } on BackupFormatException {
      rethrow;
    } catch (e) {
      throw BackupFormatException(BackupError.corrupt, e);
    }
  }

  // ---------------------------------------------------------------------
  // JSON mapping — explicit per field (not reflection), so renaming a Dart
  // field can never silently change the file format.
  // ---------------------------------------------------------------------

  static String? _date(DateTime? d) => d?.toIso8601String();
  static DateTime? _parseDate(Object? s) =>
      s == null ? null : DateTime.parse(s as String);
  static double? _double(Object? n) => (n as num?)?.toDouble();

  static T _enum<T extends Enum>(List<T> values, Object? name, T fallback) =>
      values.where((v) => v.name == name).firstOrNull ?? fallback;

  Map<String, dynamic> _settingsToJson(AppSettings s) => {
    'languageCode': s.languageCode,
    'themeId': s.themeId,
    'reminderHour': s.reminderHour,
    'reminderMinute': s.reminderMinute,
  };

  AppSettings _settingsFromJson(Map<String, dynamic> j) => AppSettings(
    languageCode: j['languageCode'] as String? ?? 'vi',
    themeId: j['themeId'] as String? ?? 'sky',
    reminderHour: j['reminderHour'] as int? ?? 8,
    reminderMinute: j['reminderMinute'] as int? ?? 0,
  );

  Map<String, dynamic> _itemToJson(TrackedItem i) => {
    'id': i.id,
    'name': i.name,
    'category': i.category.name,
    'photoId': i.photoId,
    'purchaseDate': _date(i.purchaseDate),
    'recurrenceType': i.recurrenceType.name,
    'recurrenceIntervalDays': i.recurrenceIntervalDays,
    'recurrenceIntervalValue': i.recurrenceIntervalValue,
    'currentValue': i.currentValue,
    'expiryDate': _date(i.expiryDate),
    'reminderLeadDays': i.reminderLeadDays,
    'notes': i.notes,
    'valueUnit': i.valueUnit,
    'createdAt': _date(i.createdAt),
    'updatedAt': _date(i.updatedAt),
    'valueUpdatedAt': _date(i.valueUpdatedAt),
    'baselineValue': i.baselineValue,
    'manualValue': i.manualValue,
  };

  TrackedItem _itemFromJson(Map<String, dynamic> j) => TrackedItem(
    id: j['id'] as String,
    name: j['name'] as String,
    category: _enum(ItemCategory.values, j['category'], ItemCategory.other),
    photoId: j['photoId'] as String?,
    purchaseDate: _parseDate(j['purchaseDate']),
    recurrenceType: _enum(
      RecurrenceType.values,
      j['recurrenceType'],
      RecurrenceType.none,
    ),
    recurrenceIntervalDays: j['recurrenceIntervalDays'] as int?,
    recurrenceIntervalValue: _double(j['recurrenceIntervalValue']),
    currentValue: _double(j['currentValue']),
    expiryDate: _parseDate(j['expiryDate']),
    reminderLeadDays: j['reminderLeadDays'] as int? ?? 7,
    notes: j['notes'] as String? ?? '',
    valueUnit: j['valueUnit'] as String? ?? 'km',
    createdAt: _parseDate(j['createdAt']),
    updatedAt: _parseDate(j['updatedAt']),
    valueUpdatedAt: _parseDate(j['valueUpdatedAt']),
    baselineValue: _double(j['baselineValue']),
    manualValue: _double(j['manualValue']),
  );

  Map<String, dynamic> _logToJson(MaintenanceLog l) => {
    'id': l.id,
    'itemId': l.itemId,
    'date': _date(l.date),
    'value': l.value,
    'note': l.note,
    'createdAt': _date(l.createdAt),
    'photoId': l.photoId,
  };

  MaintenanceLog _logFromJson(Map<String, dynamic> j) => MaintenanceLog(
    id: j['id'] as String,
    itemId: j['itemId'] as String,
    date: _parseDate(j['date'])!,
    value: _double(j['value']),
    note: j['note'] as String? ?? '',
    createdAt: _parseDate(j['createdAt']),
    photoId: j['photoId'] as String?,
  );
}
