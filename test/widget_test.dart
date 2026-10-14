import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:well_kept/core/models/backup_data.dart';
import 'package:well_kept/core/providers/settings_provider.dart';
import 'package:well_kept/core/providers/tracked_item_provider.dart';
import 'package:well_kept/core/utils/backup_service.dart';
import 'package:well_kept/core/utils/data_manager.dart';
import 'package:well_kept/core/utils/photo_picker_service.dart';
import 'package:well_kept/core/widgets/item_photo.dart';
import 'package:well_kept/main.dart';
import 'package:well_kept/models/app_settings.dart';
import 'package:well_kept/models/tracked_item.dart';
import 'package:well_kept/screens/responsive_item_list_screen.dart';

import 'fakes.dart';

/// The app with fakes for the platform plugins (notifications, photo
/// picker), which have no implementation under `flutter test`.
Widget _app({
  FakePhotoPicker? picker,
  FakeNotificationService? notifications,
  FakeBackupFiles? backupFiles,
}) => WellKeptApp(
  photoPicker: picker ?? FakePhotoPicker(),
  notificationService: notifications ?? FakeNotificationService(),
  backupFiles: backupFiles ?? FakeBackupFiles(),
);

TrackedItemProvider _itemProvider(WidgetTester tester) => tester
    .element(find.byType(ResponsiveItemListScreen))
    .read<TrackedItemProvider>();

/// Phone-sized surface for both LayoutBuilder (setSurfaceSize) and
/// MediaQuery (view.physicalSize) — modals decide sheet vs dialog from the
/// latter.
Future<void> _usePhoneSize(WidgetTester tester) =>
    _useSize(tester, const Size(400, 800));

Future<void> _useSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    await tester.binding.setSurfaceSize(null);
  });
}

/// Taps [finder] whose handler writes to Hive. The tap itself must run in
/// the real zone: a write started in testWidgets' fake-time zone never
/// completes, and Hive's per-box write queue then blocks every later write
/// too (including the next test's reset).
Future<void> _tapWithIO(WidgetTester tester, Finder finder) async {
  await tester.runAsync(() async {
    await tester.tap(finder);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  await tester.pumpAndSettle();
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Lưu'));
  await _tapWithIO(tester, find.text('Lưu'));
}

/// For a save that fails validation: nothing is written, so there's no
/// I/O to wait for — just pump the validation errors in.
Future<void> _tapSaveExpectingError(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Lưu'));
  await tester.tap(find.text('Lưu'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Clears all data at the start of a test. Not in setUp: for testWidgets,
/// setUp runs in the fake-time zone where real Hive I/O never completes.
Future<void> _resetData(WidgetTester tester) =>
    tester.runAsync(() => DataManager().clearAll());

void main() {
  setUpAll(() async {
    final dir = Directory.systemTemp.createTempSync('wellkept_test_');
    // Best-effort cleanup only — on Windows the Hive box file can still be
    // memory-mapped by this process when the test run ends, which makes
    // deleting it fail; that's harmless, just a leftover temp dir.
    addTearDown(() {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });
    await DataManager().initialize(hivePath: dir.path);
  });

  testWidgets('the app starts on the empty item list without crashing', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('WellKept'), findsOneWidget);
    expect(find.textContaining('Chưa có món đồ nào'), findsOneWidget);
  });

  testWidgets('an added item shows up with its remaining days', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // runAsync: addItem does real Hive file I/O, which never resolves in
    // testWidgets' fake-time zone without it.
    await tester.runAsync(() async {
      await _itemProvider(tester).addItem(
        name: 'Máy lọc nước',
        category: ItemCategory.home,
        recurrenceType: RecurrenceType.byTime,
        recurrenceIntervalDays: 90,
        purchaseDate: DateTime.now(),
      );
    });
    await tester.pumpAndSettle();

    expect(find.text('Máy lọc nước'), findsOneWidget);
    expect(find.textContaining('Còn 90 ngày'), findsOneWidget);
  });

  testWidgets('adding an item through the form shows it in the list', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên món đồ'),
      'Xe Wave',
    );
    // Defaults: vehicle, every 180 days, counted from today.
    await _tapSave(tester);

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Xe Wave'), findsOneWidget);
    expect(find.textContaining('Còn 180 ngày'), findsOneWidget);
    expect(_itemProvider(tester).items.single.category, ItemCategory.vehicle);
  });

  testWidgets('the add-item form refuses an empty name', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await _tapSaveExpectingError(tester);

    expect(find.text('Nhập tên món đồ'), findsOneWidget);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(_itemProvider(tester).items, isEmpty);
  });

  testWidgets('picking the warranty category switches to a one-off expiry '
      'date, which is then required', (WidgetTester tester) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xe cộ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bảo hành / hóa đơn').last);
    await tester.pumpAndSettle();

    expect(find.text('Một lần (hết hạn bảo hành)'), findsOneWidget);
    expect(find.text('Ngày hết hạn bảo hành'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên món đồ'),
      'Tivi',
    );
    await _tapSaveExpectingError(tester);

    expect(find.text('Chọn ngày hết hạn'), findsOneWidget);
    expect(_itemProvider(tester).items, isEmpty);
  });

  testWidgets('logging a reading through the add-log sheet updates the '
      'remaining km in the list', (WidgetTester tester) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await _itemProvider(tester).addItem(
        name: 'Xe máy',
        recurrenceType: RecurrenceType.byValue,
        recurrenceIntervalValue: 2000,
        currentValue: 15000,
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('Còn 2.000 km (mốc 17.000 km)'), findsOneWidget);

    await tester.tap(find.text('Xe máy'));
    await tester.pumpAndSettle();
    expect(find.text('Ghi bảo trì: Xe máy'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Chỉ số lúc bảo trì (km)'),
      '16000',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ghi chú'),
      'Thay nhớt',
    );
    await _tapSave(tester);

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Còn 2.000 km (mốc 18.000 km)'), findsOneWidget);

    // Reopening shows the log in the history.
    await tester.tap(find.text('Xe máy'));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử bảo trì'), findsOneWidget);
    expect(find.text('Thay nhớt'), findsOneWidget);
    expect(find.textContaining('16.000 km'), findsOneWidget);
  });

  testWidgets('editing an item through the menu updates the list', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await _itemProvider(tester).addItem(
        name: 'Máy lọc nước',
        recurrenceType: RecurrenceType.byTime,
        recurrenceIntervalDays: 90,
        purchaseDate: DateTime.now(),
      );
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Còn 90 ngày'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    // Not a value-based item, so no "update reading" entry.
    expect(find.text('Cập nhật chỉ số'), findsNothing);
    await tester.tap(find.text('Sửa'));
    await tester.pumpAndSettle();

    expect(find.text('Sửa món đồ'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Máy lọc nước'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên món đồ'),
      'Máy lọc nước RO',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Chu kỳ (ngày)'),
      '60',
    );
    await _tapSave(tester);

    expect(find.text('Máy lọc nước RO'), findsOneWidget);
    expect(find.textContaining('Còn 60 ngày'), findsOneWidget);
    expect(_itemProvider(tester).items, hasLength(1));
  });

  testWidgets('updating the reading from the menu moves toward the due point', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await _itemProvider(tester).addItem(
        name: 'Xe máy',
        recurrenceType: RecurrenceType.byValue,
        recurrenceIntervalValue: 2000,
        currentValue: 15000,
      );
    });
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cập nhật chỉ số'));
    await tester.pumpAndSettle();

    expect(find.text('Chỉ số đang lưu: 15.000 km'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Chỉ số hiện tại (km)'),
      '16500',
    );
    await _tapSave(tester);

    expect(find.text('Còn 500 km (mốc 17.000 km)'), findsOneWidget);
    expect(
      _itemProvider(tester).logsFor(_itemProvider(tester).items.single.id),
      isEmpty,
    );
  });

  testWidgets('a stale reading shows a warning on the card', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final longAgo = DateTime.now().subtract(const Duration(days: 60));
    await tester.runAsync(() async {
      await DataManager().saveItem(
        TrackedItem(
          id: 'old-car',
          name: 'Ô tô cũ',
          recurrenceType: RecurrenceType.byValue,
          recurrenceIntervalValue: 5000,
          currentValue: 40000,
          baselineValue: 40000,
          createdAt: longAgo,
          valueUpdatedAt: longAgo,
        ),
      );
    });
    _itemProvider(tester).refresh();
    await tester.pumpAndSettle();

    expect(find.text('60 ngày chưa cập nhật chỉ số'), findsOneWidget);
  });

  testWidgets('deleting an item asks for confirmation first', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await _itemProvider(tester).addItem(name: 'Nồi cơm');
    });
    await tester.pumpAndSettle();

    Future<void> openDeleteDialog() async {
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa "Nồi cơm"?'), findsOneWidget);
    }

    await openDeleteDialog();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(find.text('Nồi cơm'), findsOneWidget);

    await openDeleteDialog();
    await _tapWithIO(tester, find.widgetWithText(TextButton, 'Xóa'));
    expect(find.text('Nồi cơm'), findsNothing);
    expect(find.textContaining('Chưa có món đồ nào'), findsOneWidget);
  });

  testWidgets('the settings sheet switches and persists the theme', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt'), findsOneWidget);
    await _tapWithIO(tester, find.byTooltip('Slate'));

    final settings = tester
        .element(find.byType(ResponsiveItemListScreen))
        .read<SettingsProvider>();
    expect(settings.themeId, 'slate');
    expect(DataManager().settings.themeId, 'slate');
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor ??
          Theme.of(
            tester.element(find.byType(Scaffold)),
          ).scaffoldBackgroundColor,
      settings.themeConfig.background,
    );
  });

  testWidgets('switching the language to English re-renders the whole UI', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await _itemProvider(tester).addItem(
        name: 'Air filter',
        recurrenceType: RecurrenceType.byTime,
        recurrenceIntervalDays: 90,
        purchaseDate: DateTime.now(),
      );
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Còn 90 ngày'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await _tapWithIO(tester, find.text('English'));

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Reminder time'), findsOneWidget);
    expect(DataManager().settings.languageCode, 'en');

    Navigator.of(tester.element(find.text('Settings'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Add item'), findsOneWidget);
    expect(find.textContaining('90 days left'), findsOneWidget);
  });

  testWidgets('the settings sheet shows and persists the reminder time', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    // Vietnamese time format is 24h.
    expect(find.text('08:00'), findsOneWidget);

    // The time picker's own flow is Flutter's; drive the provider the
    // sheet calls once a time is picked, and check the sheet follows.
    final settings = tester
        .element(find.byType(ResponsiveItemListScreen))
        .read<SettingsProvider>();
    await tester.runAsync(() => settings.setReminderTime(19, 30));
    await tester.pumpAndSettle();

    expect(find.text('19:30'), findsOneWidget);
    expect(DataManager().settings.reminderHour, 19);
    expect(DataManager().settings.reminderMinute, 30);
  });

  testWidgets('adding an item with a due date schedules its reminders', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    final notifications = FakeNotificationService();
    await tester.pumpWidget(_app(notifications: notifications));
    await tester.pumpAndSettle();
    expect(notifications.initCalls, 1);
    expect(notifications.scheduled, isEmpty);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên món đồ'),
      'Máy lạnh',
    );
    await _tapSave(tester);
    // The reschedule the save triggers hops between the real zone (where
    // the save ran) and the fake one (where NotificationProvider's queue
    // was created): alternate real time and pumps until it has finished.
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }

    // 180-day interval from today, 7 days' notice: one lead reminder and
    // one on the due day, titled with the item name.
    expect(notifications.scheduled, hasLength(2));
    expect(notifications.scheduled.map((r) => r.title).toSet(), {'Máy lạnh'});
    expect(notifications.permissionRequests, 1);
  });

  testWidgets('a photo picked in the add form is saved with the item', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    final picker = FakePhotoPicker();
    await tester.pumpWidget(_app(picker: picker));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chọn từ thư viện'));
    await tester.pumpAndSettle();

    expect(picker.requests, [PhotoSource.gallery]);
    expect(find.text('Xóa ảnh'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tên món đồ'),
      'Hóa đơn tủ lạnh',
    );
    await tester.ensureVisible(find.text('Lưu'));
    // Like _tapWithIO, but the rebuild that creates the card's ItemPhoto
    // (which reads the photo from Hive) must also run in the real zone.
    await tester.runAsync(() async {
      await tester.tap(find.text('Lưu'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final item = _itemProvider(tester).items.single;
    expect(item.photoId, isNotNull);
    final stored = await tester.runAsync(
      () => _itemProvider(tester).loadPhoto(item.photoId!),
    );
    expect(stored, onePixelPng);
    expect(find.byType(ItemPhoto), findsOneWidget);
    expect(
      find.descendant(of: find.byType(ItemPhoto), matching: find.byType(Image)),
      findsOneWidget,
    );
  });

  testWidgets('a cancelled photo pick changes nothing', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app(picker: FakePhotoPicker(cancels: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();

    expect(find.text('Xóa ảnh'), findsNothing);
  });

  testWidgets('tapping a past log loads it into the form to edit it', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final item = await _itemProvider(tester).addItem(
        name: 'Xe máy',
        recurrenceType: RecurrenceType.byValue,
        recurrenceIntervalValue: 2000,
        currentValue: 15000,
      );
      await _itemProvider(tester).addLog(
        itemId: item.id,
        date: DateTime(2026, 9, 1),
        value: 15500,
        note: 'Thay nhớt',
      );
    });
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xe máy'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Thay nhớt'));
    await tester.tap(find.text('Thay nhớt'));
    await tester.pumpAndSettle();

    expect(find.text('Sửa log ngày 01/09/2026'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '15500'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Thay nhớt'),
      'Thay nhớt + lọc gió',
    );
    await _tapSave(tester);

    // Saving an edit returns the sheet to "add" mode instead of closing it.
    expect(find.text('Ghi bảo trì: Xe máy'), findsOneWidget);
    expect(find.text('Thay nhớt + lọc gió'), findsOneWidget);
    final log = _itemProvider(
      tester,
    ).logsFor(_itemProvider(tester).items.single.id).single;
    expect(log.note, 'Thay nhớt + lọc gió');
    expect(log.value, 15500);
  });

  testWidgets('searching narrows the list, ignoring accents', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await _itemProvider(tester).addItem(name: 'Lõi lọc nước');
      await _itemProvider(tester).addItem(name: 'Nồi cơm điện');
    });
    await tester.pumpAndSettle();

    final search = find.widgetWithText(TextField, 'Tìm theo tên, ghi chú');
    await tester.enterText(search, 'loc nuoc');
    await tester.pumpAndSettle();
    expect(find.text('Lõi lọc nước'), findsOneWidget);
    expect(find.text('Nồi cơm điện'), findsNothing);

    await tester.enterText(search, 'không có gì');
    await tester.pumpAndSettle();
    expect(find.text('Không có món đồ nào khớp bộ lọc.'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Xóa bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Lõi lọc nước'), findsOneWidget);
    expect(find.text('Nồi cơm điện'), findsOneWidget);
  });

  testWidgets('category chips filter the list', (WidgetTester tester) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await _itemProvider(
        tester,
      ).addItem(name: 'Xe Wave', category: ItemCategory.vehicle);
      await _itemProvider(
        tester,
      ).addItem(name: 'Tủ lạnh', category: ItemCategory.home);
    });
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Xe cộ'));
    await tester.pumpAndSettle();
    expect(find.text('Xe Wave'), findsOneWidget);
    expect(find.text('Tủ lạnh'), findsNothing);

    await tester.tap(find.widgetWithText(FilterChip, 'Xe cộ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh'), findsOneWidget);
  });

  testWidgets('tapping a reminder while running opens that item', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    final notifications = FakeNotificationService();
    await tester.pumpWidget(_app(notifications: notifications));
    await tester.pumpAndSettle();
    late TrackedItem item;
    await tester.runAsync(() async {
      item = await _itemProvider(tester).addItem(name: 'Máy giặt');
    });
    await tester.pumpAndSettle();

    notifications.tap(item.id);
    await tester.pumpAndSettle();

    expect(find.text('Ghi bảo trì: Máy giặt'), findsOneWidget);
  });

  testWidgets('a reminder for a deleted item is ignored', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    final notifications = FakeNotificationService();
    await tester.pumpWidget(_app(notifications: notifications));
    await tester.pumpAndSettle();

    notifications.tap('gone');
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('launching the app from a reminder opens that item', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _usePhoneSize(tester);
    await tester.runAsync(
      () => DataManager().saveItem(TrackedItem(id: 'wm', name: 'Máy giặt')),
    );

    await tester.pumpWidget(
      _app(notifications: FakeNotificationService(launchedFrom: 'wm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ghi bảo trì: Máy giặt'), findsOneWidget);
  });

  group('backup', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
    }

    testWidgets('exporting saves a backup containing the items', (
      WidgetTester tester,
    ) async {
      await _resetData(tester);
      await _usePhoneSize(tester);
      final files = FakeBackupFiles();
      await tester.pumpWidget(_app(backupFiles: files));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => _itemProvider(tester).addItem(name: 'Máy lọc nước'),
      );
      await tester.pumpAndSettle();

      await openSettings(tester);
      await tester.ensureVisible(find.text('Xuất file sao lưu'));
      await _tapWithIO(tester, find.text('Xuất file sao lưu'));

      expect(
        files.savedName,
        matches(RegExp(r'^wellkept-backup-\d{8}-\d{4}\.zip$')),
      );
      final data = const BackupService().decode(files.savedBytes!);
      expect(data.items.single.name, 'Máy lọc nước');
      expect(find.text('Đã lưu file sao lưu.'), findsOneWidget);
    });

    testWidgets('restoring with "merge" adds the backup items', (
      WidgetTester tester,
    ) async {
      await _resetData(tester);
      await _usePhoneSize(tester);
      final files = FakeBackupFiles(
        pickResult: const BackupService().encode(
          BackupData(
            items: [TrackedItem(id: 'old', name: 'Từ máy cũ')],
            logs: const [],
            settings: AppSettings.initial(),
            photos: const {},
          ),
        ),
      );
      await tester.pumpWidget(_app(backupFiles: files));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => _itemProvider(tester).addItem(name: 'Đang có'),
      );
      await tester.pumpAndSettle();

      await openSettings(tester);
      await tester.ensureVisible(find.text('Khôi phục từ file'));
      await tester.tap(find.text('Khôi phục từ file'));
      await tester.pumpAndSettle();

      expect(find.text('Khôi phục dữ liệu'), findsOneWidget);
      expect(
        find.textContaining('File có 1 món đồ và 0 lần bảo trì.'),
        findsOneWidget,
      );
      await _tapWithIO(tester, find.widgetWithText(TextButton, 'Gộp'));

      expect(find.text('Đã khôi phục 1 món đồ.'), findsOneWidget);
      expect(
        _itemProvider(tester).items.map((i) => i.name),
        unorderedEquals(['Đang có', 'Từ máy cũ']),
      );
    });

    testWidgets('a file that is not a backup is rejected with a message', (
      WidgetTester tester,
    ) async {
      await _resetData(tester);
      await _usePhoneSize(tester);
      final files = FakeBackupFiles(
        pickResult: Uint8List.fromList(utf8.encode('not a zip')),
      );
      await tester.pumpWidget(_app(backupFiles: files));
      await tester.pumpAndSettle();

      await openSettings(tester);
      await tester.ensureVisible(find.text('Khôi phục từ file'));
      await tester.tap(find.text('Khôi phục từ file'));
      await tester.pumpAndSettle();

      expect(
        find.text('File này không phải bản sao lưu WellKept.'),
        findsOneWidget,
      );
      expect(find.text('Khôi phục dữ liệu'), findsNothing);
    });
  });

  testWidgets('on a desktop-sized screen the add-item form opens as a dialog', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _useSize(tester, const Size(1280, 900));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Thêm món đồ'), findsWidgets);
  });
}
