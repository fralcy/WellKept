import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/models/backup_data.dart';
import 'package:well_kept/core/utils/backup_service.dart';
import 'package:well_kept/core/utils/data_manager.dart';
import 'package:well_kept/models/app_settings.dart';
import 'package:well_kept/models/maintenance_log.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  const service = BackupService();

  final fullItem = TrackedItem(
    id: 'bike',
    name: 'Xe máy Wave',
    category: ItemCategory.vehicle,
    photoId: 'p-item',
    purchaseDate: DateTime(2024, 3, 5),
    recurrenceType: RecurrenceType.byValue,
    recurrenceIntervalDays: 30,
    recurrenceIntervalValue: 2000.5,
    currentValue: 16200,
    expiryDate: DateTime(2027, 1, 2),
    reminderLeadDays: 3,
    notes: 'Lọc dầu 15400-KYJ',
    valueUnit: 'km',
    createdAt: DateTime(2024, 3, 5, 10, 30),
    updatedAt: DateTime(2026, 9, 1, 8),
    valueUpdatedAt: DateTime(2026, 9, 1, 8),
    baselineValue: 15000,
    manualValue: 16200,
  );
  final fullLog = MaintenanceLog(
    id: 'log1',
    itemId: 'bike',
    date: DateTime(2026, 8, 1),
    value: 15800,
    note: 'Thay nhớt',
    createdAt: DateTime(2026, 8, 1, 9),
    photoId: 'p-log',
  );
  final photos = {
    'p-item': Uint8List.fromList([1, 2, 3]),
    'p-log': Uint8List.fromList(List.generate(5000, (i) => i % 256)),
  };

  BackupData sample() => BackupData(
    items: [
      fullItem,
      TrackedItem(id: 'n', name: 'Bare minimum'),
    ],
    logs: [fullLog],
    settings: AppSettings(
      languageCode: 'en',
      themeId: 'slate',
      reminderHour: 19,
      reminderMinute: 30,
    ),
    photos: photos,
  );

  Uint8List zipWith(Map<String, List<int>> files) {
    final archive = Archive();
    files.forEach(
      (name, bytes) => archive.addFile(ArchiveFile.bytes(name, bytes)),
    );
    return ZipEncoder().encodeBytes(archive);
  }

  BackupError? errorOf(Uint8List bytes) {
    try {
      service.decode(bytes);
      return null;
    } on BackupFormatException catch (e) {
      return e.error;
    }
  }

  test('encode → decode round-trips every field and every photo', () {
    final decoded = service.decode(service.encode(sample()));

    final item = decoded.items.firstWhere((i) => i.id == 'bike');
    expect(item.name, fullItem.name);
    expect(item.category, ItemCategory.vehicle);
    expect(item.photoId, 'p-item');
    expect(item.purchaseDate, fullItem.purchaseDate);
    expect(item.recurrenceType, RecurrenceType.byValue);
    expect(item.recurrenceIntervalDays, 30);
    expect(item.recurrenceIntervalValue, 2000.5);
    expect(item.currentValue, 16200);
    expect(item.expiryDate, fullItem.expiryDate);
    expect(item.reminderLeadDays, 3);
    expect(item.notes, 'Lọc dầu 15400-KYJ');
    expect(item.valueUnit, 'km');
    expect(item.createdAt, fullItem.createdAt);
    expect(item.updatedAt, fullItem.updatedAt);
    expect(item.valueUpdatedAt, fullItem.valueUpdatedAt);
    expect(item.baselineValue, 15000);
    expect(item.manualValue, 16200);

    final bare = decoded.items.firstWhere((i) => i.id == 'n');
    expect(bare.photoId, isNull);
    expect(bare.recurrenceType, RecurrenceType.none);

    final log = decoded.logs.single;
    expect(log.id, 'log1');
    expect(log.itemId, 'bike');
    expect(log.date, fullLog.date);
    expect(log.value, 15800);
    expect(log.note, 'Thay nhớt');
    expect(log.createdAt, fullLog.createdAt);
    expect(log.photoId, 'p-log');

    expect(decoded.settings.languageCode, 'en');
    expect(decoded.settings.themeId, 'slate');
    expect(decoded.settings.reminderHour, 19);
    expect(decoded.settings.reminderMinute, 30);

    expect(decoded.photos.keys, unorderedEquals(['p-item', 'p-log']));
    expect(decoded.photos['p-log'], photos['p-log']);
  });

  test('the archive holds wellkept.json with the schema version', () {
    final archive = ZipDecoder().decodeBytes(service.encode(sample()));
    final json =
        jsonDecode(utf8.decode(archive.findFile('wellkept.json')!.readBytes()!))
            as Map<String, dynamic>;
    expect(json['schemaVersion'], BackupService.schemaVersion);
    expect(archive.findFile('photos/p-item'), isNotNull);
  });

  test('rejects a file that is not a zip', () {
    expect(
      errorOf(Uint8List.fromList(utf8.encode('hello'))),
      BackupError.notABackup,
    );
  });

  test('rejects a zip without wellkept.json', () {
    expect(
      errorOf(
        zipWith({
          'other.txt': [1],
        }),
      ),
      BackupError.notABackup,
    );
  });

  test('rejects a backup from a newer schema version', () {
    final bytes = zipWith({
      'wellkept.json': utf8.encode(
        jsonEncode({
          'schemaVersion': BackupService.schemaVersion + 1,
          'settings': {},
          'items': [],
          'logs': [],
        }),
      ),
    });
    expect(errorOf(bytes), BackupError.newerVersion);
  });

  test('rejects unparseable or malformed contents as corrupt', () {
    expect(
      errorOf(zipWith({'wellkept.json': utf8.encode('{not json')})),
      BackupError.corrupt,
    );
    expect(
      errorOf(
        zipWith({
          'wellkept.json': utf8.encode(
            jsonEncode({
              'schemaVersion': 1,
              'settings': {},
              'items': [
                {'name': 'no id'},
              ],
              'logs': [],
            }),
          ),
        }),
      ),
      BackupError.corrupt,
    );
  });

  group('DataManager backup', () {
    setUpAll(() async {
      final dir = Directory.systemTemp.createTempSync('wellkept_backup_test_');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      });
      await DataManager().initialize(hivePath: dir.path);
    });

    setUp(() => DataManager().clearAll());

    test('collectBackup includes referenced photos only', () async {
      final dm = DataManager();
      await dm.saveItem(TrackedItem(id: 'a', name: 'a', photoId: 'used'));
      await dm.savePhotoBytes('used', Uint8List.fromList([1]));
      await dm.savePhotoBytes('orphan', Uint8List.fromList([2]));

      final data = await dm.collectBackup();

      expect(data.items.single.id, 'a');
      expect(data.photos.keys, ['used']);
    });

    test('replace wipes current data and takes the backup settings', () async {
      final dm = DataManager();
      await dm.saveItem(TrackedItem(id: 'local', name: 'local'));
      await dm.savePhotoBytes('local-photo', Uint8List.fromList([9]));

      await dm.restoreBackup(sample(), replace: true);

      expect(dm.getAllItems().map((i) => i.id), unorderedEquals(['bike', 'n']));
      expect(dm.getAllLogs().single.id, 'log1');
      expect(await dm.getPhotoBytes('p-item'), [1, 2, 3]);
      expect(await dm.getPhotoBytes('local-photo'), isNull);
      expect(dm.settings.themeId, 'slate');
    });

    test('merge keeps local data and settings, overwriting same ids', () async {
      final dm = DataManager();
      await dm.saveItem(TrackedItem(id: 'local', name: 'local'));
      await dm.saveItem(TrackedItem(id: 'bike', name: 'old name'));

      await dm.restoreBackup(sample(), replace: false);

      expect(
        dm.getAllItems().map((i) => i.id),
        unorderedEquals(['local', 'bike', 'n']),
      );
      expect(dm.getItem('bike')!.name, 'Xe máy Wave');
      expect(dm.settings.themeId, 'sky');
    });

    test('export from one device restores identically on another', () async {
      final dm = DataManager();
      await dm.restoreBackup(sample(), replace: true);
      final bytes = service.encode(await dm.collectBackup());

      await dm.clearAll();
      await dm.restoreBackup(service.decode(bytes), replace: true);

      expect(dm.getItem('bike')!.manualValue, 16200);
      expect(await dm.getPhotoBytes('p-log'), photos['p-log']);
    });
  });
}
