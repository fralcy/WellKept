import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:well_kept/core/providers/settings_provider.dart';
import 'package:well_kept/core/providers/tracked_item_provider.dart';
import 'package:well_kept/core/utils/data_manager.dart';
import 'package:well_kept/main.dart';
import 'package:well_kept/models/tracked_item.dart';
import 'package:well_kept/screens/responsive_item_list_screen.dart';

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
    await tester.pumpWidget(const WellKeptApp());
    await tester.pumpAndSettle();

    expect(find.text('WellKept'), findsOneWidget);
    expect(find.textContaining('Chưa có món đồ nào'), findsOneWidget);
  });

  testWidgets('an added item shows up with its remaining days', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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
    await tester.pumpWidget(const WellKeptApp());
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

  testWidgets('the theme menu switches and persists the theme', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await tester.pumpWidget(const WellKeptApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.palette_outlined));
    await tester.pumpAndSettle();
    await _tapWithIO(tester, find.text('Slate'));

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

  testWidgets('on a desktop-sized screen the add-item form opens as a dialog', (
    WidgetTester tester,
  ) async {
    await _resetData(tester);
    await _useSize(tester, const Size(1280, 900));
    await tester.pumpWidget(const WellKeptApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Thêm món đồ'), findsWidgets);
  });
}
