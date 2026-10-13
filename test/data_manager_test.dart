import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/providers/settings_provider.dart';
import 'package:well_kept/core/utils/data_manager.dart';
import 'package:well_kept/core/utils/photo_storage_service.dart';
import 'package:well_kept/models/maintenance_log.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('wellkept_dm_test_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    await DataManager().initialize(hivePath: dir.path);
  });

  setUp(() => DataManager().clearAll());

  test('initialize is idempotent', () async {
    await DataManager().initialize(hivePath: Directory.systemTemp.path);
    expect(DataManager().settings.themeId, 'sky');
  });

  test('every TrackedItem field round-trips through Hive', () async {
    final item = TrackedItem.create(
      id: 'i1',
      name: 'Xe máy',
      category: ItemCategory.vehicle,
      photoId: 'p1',
      purchaseDate: DateTime(2025, 5, 6),
      recurrenceType: RecurrenceType.byValue,
      recurrenceIntervalDays: 30,
      recurrenceIntervalValue: 2000.5,
      currentValue: 15000,
      expiryDate: DateTime(2027, 1, 2),
      reminderLeadDays: 3,
      notes: 'Lọc dầu 15400-KYJ',
      valueUnit: 'giờ',
    );
    await DataManager().saveItem(item);

    final read = DataManager().getItem('i1')!;
    expect(read.name, 'Xe máy');
    expect(read.category, ItemCategory.vehicle);
    expect(read.photoId, 'p1');
    expect(read.purchaseDate, DateTime(2025, 5, 6));
    expect(read.recurrenceType, RecurrenceType.byValue);
    expect(read.recurrenceIntervalDays, 30);
    expect(read.recurrenceIntervalValue, 2000.5);
    expect(read.currentValue, 15000);
    expect(read.expiryDate, DateTime(2027, 1, 2));
    expect(read.reminderLeadDays, 3);
    expect(read.notes, 'Lọc dầu 15400-KYJ');
    expect(read.valueUnit, 'giờ');
  });

  test('MaintenanceLog round-trips and deleteLogsForItem is scoped', () async {
    await DataManager().saveLog(
      MaintenanceLog.create(
        id: 'l1',
        itemId: 'a',
        date: DateTime(2026, 1, 1),
        value: 100,
        note: 'Thay dầu',
      ),
    );
    await DataManager().saveLog(
      MaintenanceLog.create(id: 'l2', itemId: 'b', date: DateTime(2026, 2, 1)),
    );

    final log = DataManager().getLogsForItem('a').single;
    expect(log.value, 100);
    expect(log.note, 'Thay dầu');

    await DataManager().deleteLogsForItem('a');
    expect(DataManager().getLogsForItem('a'), isEmpty);
    expect(DataManager().getAllLogs().map((l) => l.id), ['l2']);
  });

  test('copyWith keeps id/createdAt and bumps updatedAt', () async {
    final item = TrackedItem(
      id: 'x',
      name: 'Cũ',
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
    );
    final updated = item.copyWith(name: 'Mới');
    expect(updated.id, 'x');
    expect(updated.name, 'Mới');
    expect(updated.createdAt, DateTime(2020));
    expect(updated.updatedAt.isAfter(DateTime(2020)), isTrue);
  });

  group('PhotoStorageService', () {
    PhotoStorageService service() => PhotoStorageService();

    test('save/load/delete round-trips bytes under a new id', () async {
      final bytes = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final id = await service().save(bytes);

      expect(id, isNotEmpty);
      expect(await service().load(id), bytes);

      await service().delete(id);
      expect(await service().load(id), isNull);
    });

    test('each save gets a distinct id', () async {
      final a = await service().save(Uint8List.fromList([1]));
      final b = await service().save(Uint8List.fromList([2]));
      expect(a, isNot(b));
      expect(await service().load(a), [1]);
      expect(await service().load(b), [2]);
    });
  });

  group('SettingsProvider', () {
    test('defaults to vi + sky theme', () {
      final settings = SettingsProvider();
      expect(settings.languageCode, 'vi');
      expect(settings.themeId, 'sky');
      expect(settings.themeConfig.id, 'sky');
    });

    test('setThemeId persists and notifies', () async {
      final settings = SettingsProvider();
      var notified = 0;
      settings.addListener(() => notified++);

      await settings.setThemeId('slate');

      expect(notified, 1);
      expect(DataManager().settings.themeId, 'slate');
      expect(SettingsProvider().themeConfig.id, 'slate');
    });

    test('an unknown theme id falls back to the first preset', () async {
      final settings = SettingsProvider();
      await settings.setThemeId('does-not-exist');
      expect(settings.themeConfig.id, 'sky');
    });

    test('setLanguageCode persists', () async {
      await SettingsProvider().setLanguageCode('en');
      expect(DataManager().settings.languageCode, 'en');
    });

    test('clearAll resets settings to defaults', () async {
      await SettingsProvider().setThemeId('mint');
      await DataManager().clearAll();
      expect(DataManager().settings.themeId, 'sky');
    });
  });
}
