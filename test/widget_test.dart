import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:well_kept/core/providers/tracked_item_provider.dart';
import 'package:well_kept/core/utils/data_manager.dart';
import 'package:well_kept/main.dart';
import 'package:well_kept/models/tracked_item.dart';
import 'package:well_kept/screens/responsive_item_list_screen.dart';

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
    await tester.pumpWidget(const WellKeptApp());
    await tester.pumpAndSettle();

    expect(find.text('WellKept'), findsOneWidget);
    expect(find.textContaining('Chưa có món đồ nào'), findsOneWidget);
  });

  testWidgets('an added item shows up with its remaining days', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const WellKeptApp());
    await tester.pumpAndSettle();

    final provider = tester
        .element(find.byType(ResponsiveItemListScreen))
        .read<TrackedItemProvider>();
    // runAsync: addItem does real Hive file I/O, which never resolves in
    // testWidgets' fake-time zone without it.
    await tester.runAsync(() async {
      await provider.addItem(
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

  testWidgets('the add-item button opens the add-item form', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const WellKeptApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Tên món đồ'), findsOneWidget);
  });
}
