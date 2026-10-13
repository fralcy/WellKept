import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/providers/tracked_item_provider.dart';
import 'package:well_kept/core/utils/data_manager.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  late TrackedItemProvider provider;
  final today = DateTime(2026, 10, 13);

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('wellkept_provider_test_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    await DataManager().initialize(hivePath: dir.path);
  });

  setUp(() async {
    await DataManager().clearAll();
    provider = TrackedItemProvider();
  });

  Future<TrackedItem> addBike({double currentValue = 15000}) =>
      provider.addItem(
        name: 'Xe máy',
        category: ItemCategory.vehicle,
        recurrenceType: RecurrenceType.byValue,
        recurrenceIntervalValue: 2000,
        currentValue: currentValue,
      );

  test('addItem persists the item and notifies listeners', () async {
    var notified = 0;
    provider.addListener(() => notified++);

    final item = await addBike();

    expect(provider.items.map((i) => i.id), [item.id]);
    expect(DataManager().getItem(item.id)?.name, 'Xe máy');
    expect(notified, 1);
    // A fresh provider reads the same data back from Hive.
    expect(TrackedItemProvider().items.map((i) => i.id), [item.id]);
  });

  test('addLog with a higher reading advances the item currentValue', () async {
    final item = await addBike();

    await provider.addLog(
      itemId: item.id,
      date: DateTime(2026, 10, 1),
      value: 16000,
    );

    expect(DataManager().getItem(item.id)?.currentValue, 16000);
    final status = provider.statusFor(provider.items.single, today: today);
    expect(status.nextDueValue, 18000);
    expect(status.remainingValue, 2000);
  });

  test('addLog with a lower reading (an old log) keeps currentValue', () async {
    final item = await addBike(currentValue: 15000);

    await provider.addLog(
      itemId: item.id,
      date: DateTime(2025, 1, 1),
      value: 9000,
    );

    expect(DataManager().getItem(item.id)?.currentValue, 15000);
  });

  test('logsFor returns only that item\'s logs, newest first', () async {
    final a = await addBike();
    final b = await addBike();
    await provider.addLog(itemId: a.id, date: DateTime(2026, 1, 1));
    await provider.addLog(itemId: a.id, date: DateTime(2026, 6, 1));
    await provider.addLog(itemId: b.id, date: DateTime(2026, 3, 1));

    expect(provider.logsFor(a.id).map((l) => l.date), [
      DateTime(2026, 6, 1),
      DateTime(2026, 1, 1),
    ]);
    expect(provider.logsFor(b.id), hasLength(1));
  });

  test('deleteLog removes it and the due status falls back', () async {
    final item = await provider.addItem(
      name: 'Máy lạnh',
      recurrenceType: RecurrenceType.byTime,
      recurrenceIntervalDays: 180,
      purchaseDate: DateTime(2026, 1, 1),
    );
    final log = await provider.addLog(
      itemId: item.id,
      date: DateTime(2026, 8, 1),
    );
    expect(
      provider.statusFor(item, today: today).nextDueDate,
      DateTime(2027, 1, 28),
    );

    await provider.deleteLog(log.id);

    expect(provider.logsFor(item.id), isEmpty);
    expect(
      provider.statusFor(item, today: today).nextDueDate,
      DateTime(2026, 6, 30),
    );
  });

  test(
    'deleteItem also deletes its logs and photo, not other items\' logs',
    () async {
      final keep = await addBike();
      final doomed = await addBike();
      const photoId = 'photo-1';
      await DataManager().savePhotoBytes(
        photoId,
        Uint8List.fromList([1, 2, 3]),
      );
      await provider.updateItem(doomed.copyWith(photoId: () => photoId));
      await provider.addLog(itemId: doomed.id, date: DateTime(2026, 1, 1));
      await provider.addLog(itemId: keep.id, date: DateTime(2026, 1, 1));

      await provider.deleteItem(doomed.id);

      expect(provider.items.map((i) => i.id), [keep.id]);
      expect(DataManager().getLogsForItem(doomed.id), isEmpty);
      expect(DataManager().getLogsForItem(keep.id), hasLength(1));
      expect(await DataManager().getPhotoBytes(photoId), isNull);
    },
  );

  test('itemsByUrgency: overdue first, then least interval left, '
      'no-due-point items last by name', () async {
    await provider.addItem(name: 'Z không nhắc');
    await provider.addItem(name: 'A không nhắc');
    await provider.addItem(
      name: 'Còn nhiều',
      recurrenceType: RecurrenceType.byTime,
      recurrenceIntervalDays: 100,
      purchaseDate: DateTime(2026, 10, 3), // 90/100 left
    );
    await provider.addItem(
      name: 'Quá hạn',
      recurrenceType: RecurrenceType.byTime,
      recurrenceIntervalDays: 100,
      purchaseDate: DateTime(2026, 6, 1),
    );
    await provider.addItem(
      name: 'Sắp tới',
      recurrenceType: RecurrenceType.byValue,
      recurrenceIntervalValue: 1000,
      currentValue: 900, // baseline = current, so 1000/1000 left
    );
    final soon = provider.items.firstWhere((i) => i.name == 'Sắp tới');
    await provider.addLog(itemId: soon.id, date: today, value: 100);
    // Baseline is now the logged 100 while the reading stays 900:
    // 200/1000 left.

    expect(provider.itemsByUrgency(today: today).map((i) => i.name), [
      'Quá hạn',
      'Sắp tới',
      'Còn nhiều',
      'A không nhắc',
      'Z không nhắc',
    ]);
  });

  test(
    'updateReading sets the reading and its timestamp without a log',
    () async {
      final item = await addBike();
      final before = DateTime.now();

      await provider.updateReading(item.id, 16200);

      final saved = DataManager().getItem(item.id)!;
      expect(saved.currentValue, 16200);
      expect(saved.valueUpdatedAt!.isBefore(before), isFalse);
      expect(provider.logsFor(item.id), isEmpty);
      // Regression: with no log yet, the baseline must stay at the reading
      // entered at creation (15000), not follow the updated reading —
      // otherwise the due point would move away as fast as the bike does.
      expect(saved.baselineValue, 15000);
      final status = provider.statusFor(provider.items.single);
      expect(status.currentValue, 16200);
      expect(status.nextDueValue, 17000);
      expect(status.remainingValue, 800);
      expect(status.isReadingStale, isFalse);
    },
  );

  test('updateReading after a log moves toward the due point', () async {
    final item = await addBike(currentValue: 15000);
    await provider.addLog(
      itemId: item.id,
      date: DateTime(2026, 9, 1),
      value: 15000,
    );

    await provider.updateReading(item.id, 16500);

    final status = provider.statusFor(provider.items.single);
    expect(status.nextDueValue, 17000);
    expect(status.remainingValue, 500);
  });

  test('updateReading on a missing item is a no-op', () async {
    await provider.updateReading('nope', 1);
    expect(provider.items, isEmpty);
  });

  test(
    'updateItem can clear fields left over from another recurrence type',
    () async {
      final item = await addBike();
      await provider.updateItem(
        item.copyWith(
          recurrenceType: RecurrenceType.byTime,
          recurrenceIntervalDays: () => 90,
          recurrenceIntervalValue: () => null,
          currentValue: () => null,
        ),
      );

      final saved = DataManager().getItem(item.id)!;
      expect(saved.recurrenceType, RecurrenceType.byTime);
      expect(saved.recurrenceIntervalDays, 90);
      expect(saved.recurrenceIntervalValue, isNull);
      expect(saved.currentValue, isNull);
    },
  );

  group('setItemPhoto', () {
    test('stores the bytes and points the item at them', () async {
      final item = await addBike();
      await provider.setItemPhoto(item.id, Uint8List.fromList([1, 2, 3]));

      final photoId = provider.items.single.photoId;
      expect(photoId, isNotNull);
      expect(await provider.loadPhoto(photoId!), [1, 2, 3]);
    });

    test('replacing a photo deletes the old bytes', () async {
      final item = await addBike();
      await provider.setItemPhoto(item.id, Uint8List.fromList([1]));
      final oldId = provider.items.single.photoId!;

      await provider.setItemPhoto(item.id, Uint8List.fromList([2]));
      final newId = provider.items.single.photoId!;

      expect(newId, isNot(oldId));
      expect(await provider.loadPhoto(newId), [2]);
      expect(await provider.loadPhoto(oldId), isNull);
    });

    test('null removes the photo and its bytes', () async {
      final item = await addBike();
      await provider.setItemPhoto(item.id, Uint8List.fromList([1]));
      final oldId = provider.items.single.photoId!;

      await provider.setItemPhoto(item.id, null);

      expect(provider.items.single.photoId, isNull);
      expect(await provider.loadPhoto(oldId), isNull);
    });

    test('keeps the rest of the item untouched', () async {
      final item = await addBike(currentValue: 15000);
      await provider.setItemPhoto(item.id, Uint8List.fromList([1]));

      final saved = provider.items.single;
      expect(saved.name, 'Xe máy');
      expect(saved.currentValue, 15000);
      expect(saved.baselineValue, 15000);
    });
  });

  test('refresh reloads data written behind the provider\'s back', () async {
    final other = TrackedItemProvider();
    await other.addItem(name: 'Ghi từ chỗ khác');
    expect(provider.items, isEmpty);

    provider.refresh();

    expect(provider.items.map((i) => i.name), ['Ghi từ chỗ khác']);
  });
}
