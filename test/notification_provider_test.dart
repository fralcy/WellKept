import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/providers/notification_provider.dart';
import 'package:well_kept/core/providers/settings_provider.dart';
import 'package:well_kept/core/providers/tracked_item_provider.dart';
import 'package:well_kept/core/utils/data_manager.dart';
import 'package:well_kept/models/tracked_item.dart';

import 'fakes.dart';

void main() {
  late TrackedItemProvider items;
  late SettingsProvider settings;
  late FakeNotificationService service;
  late NotificationProvider notifications;
  final now = DateTime(2026, 10, 13, 9, 30);

  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('wellkept_notif_test_');
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    await DataManager().initialize(hivePath: dir.path);
  });

  setUp(() async {
    await DataManager().clearAll();
    items = TrackedItemProvider();
    settings = SettingsProvider();
    service = FakeNotificationService();
    notifications = NotificationProvider(
      itemProvider: items,
      settingsProvider: settings,
      notificationService: service,
      clock: () => now,
    );
  });

  tearDown(() => notifications.dispose());

  Future<TrackedItem> addFilter() => items.addItem(
    name: 'Lõi lọc nước',
    recurrenceType: RecurrenceType.byTime,
    recurrenceIntervalDays: 30,
    purchaseDate: DateTime(2026, 10, 13), // due 2026-11-12
  );

  /// Lets listener-triggered reschedules (fire-and-forget) finish.
  Future<void> settle() => notifications.rescheduleAll();

  test('init with no items schedules nothing and asks no permission', () async {
    await notifications.init();

    expect(service.initCalls, 1);
    expect(service.replaceCalls, 1);
    expect(service.scheduled, isEmpty);
    expect(service.permissionRequests, 0);
  });

  test(
    'adding an item reschedules, asking permission only the first time',
    () async {
      await notifications.init();

      await addFilter();
      await settle();
      expect(service.scheduled.map((r) => r.fireAt), [
        DateTime(2026, 11, 5, 8),
        DateTime(2026, 11, 12, 8),
      ]);
      expect(service.permissionRequests, 1);

      await addFilter();
      await settle();
      expect(service.scheduled, hasLength(4));
      expect(service.permissionRequests, 1);
      expect(notifications.scheduled, hasLength(4));
    },
  );

  test('changing the reminder time reschedules at the new time', () async {
    await addFilter();
    await notifications.init();

    await settings.setReminderTime(20, 45);
    await settle();

    expect(service.scheduled.map((r) => r.fireAt), [
      DateTime(2026, 11, 5, 20, 45),
      DateTime(2026, 11, 12, 20, 45),
    ]);
  });

  test('changing the language re-renders the notification text', () async {
    await addFilter();
    await notifications.init();
    expect(service.scheduled.last.body, 'Hôm nay tới hạn bảo trì');
    expect(service.lastChannelName, 'Nhắc mốc bảo trì');

    await settings.setLanguageCode('en');
    await settle();

    expect(service.scheduled.last.body, 'Maintenance due today');
    expect(service.lastChannelName, 'Maintenance reminders');
  });

  test(
    'logging maintenance moves the reminders to the next due date',
    () async {
      final item = await addFilter();
      await notifications.init();

      await items.addLog(itemId: item.id, date: DateTime(2026, 11, 1));
      await settle();

      // Next due 2026-12-01, lead 7 days → 2026-11-24.
      expect(service.scheduled.map((r) => r.fireAt), [
        DateTime(2026, 11, 24, 8),
        DateTime(2026, 12, 1, 8),
      ]);
    },
  );

  test('deleting the last item clears the queue', () async {
    final item = await addFilter();
    await notifications.init();
    expect(service.scheduled, isNotEmpty);

    await items.deleteItem(item.id);
    await settle();

    expect(service.scheduled, isEmpty);
  });

  test('a reminder tap while running becomes the pending item', () async {
    await notifications.init();
    expect(notifications.pendingItemId.value, isNull);

    service.tap('item-42');
    await Future<void>.delayed(Duration.zero);

    expect(notifications.pendingItemId.value, 'item-42');
  });

  test('launching the app from a reminder sets the pending item', () async {
    final launched = NotificationProvider(
      itemProvider: items,
      settingsProvider: settings,
      notificationService: FakeNotificationService(launchedFrom: 'item-7'),
      clock: () => now,
    );
    addTearDown(launched.dispose);

    await launched.init();

    expect(launched.pendingItemId.value, 'item-7');
  });

  test('a failing init leaves the app working and schedules nothing', () async {
    final failing = _FailingInitService();
    final provider = NotificationProvider(
      itemProvider: items,
      settingsProvider: settings,
      notificationService: failing,
      clock: () => now,
    );
    addTearDown(provider.dispose);

    await provider.init();
    await addFilter();

    expect(failing.replaceCalls, 0);
  });
}

class _FailingInitService extends FakeNotificationService {
  @override
  Future<void> init() async => throw StateError('no plugin');
}
