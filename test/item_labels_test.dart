import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/l10n/app_localizations.dart';
import 'package:well_kept/core/models/due_status.dart';
import 'package:well_kept/core/utils/item_labels.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  final vi = lookupAppLocalizations(const Locale('vi'));
  final en = lookupAppLocalizations(const Locale('en'));
  final item = TrackedItem(id: 'i', name: 'i', valueUnit: 'km');

  test('formatValue uses the locale separators, at most one decimal', () {
    expect(formatValue(vi, 2000), '2.000');
    expect(formatValue(vi, 1500.5), '1.500,5');
    expect(formatValue(vi, 12.34), '12,3');
    expect(formatValue(en, 1500.5), '1,500.5');
  });

  test('formatDate is dd/MM/yyyy in Vietnamese, spelled-out in English', () {
    expect(formatDate(vi, DateTime(2026, 3, 5)), '05/03/2026');
    expect(formatDate(en, DateTime(2026, 3, 5)), 'Mar 5, 2026');
  });

  test('category and recurrence labels are localized', () {
    expect(categoryLabel(vi, ItemCategory.warranty), 'Bảo hành / hóa đơn');
    expect(categoryLabel(en, ItemCategory.warranty), 'Warranty / receipt');
    expect(
      recurrenceLabel(en, RecurrenceType.byValue),
      'Every N units (km...)',
    );
  });

  test('staleReadingWarning only when the reading is stale', () {
    const stale = DueStatus(
      type: RecurrenceType.byValue,
      daysSinceReading: 45,
      isReadingStale: true,
    );
    expect(staleReadingWarning(vi, stale), '45 ngày chưa cập nhật chỉ số');
    expect(staleReadingWarning(en, stale), 'Reading not updated for 45 days');
    expect(
      staleReadingWarning(
        vi,
        const DueStatus(type: RecurrenceType.byValue, daysSinceReading: 3),
      ),
      isNull,
    );
  });

  group('dueSummary', () {
    test('byTime: remaining, today, overdue', () {
      final remaining = DueStatus(
        type: RecurrenceType.byTime,
        nextDueDate: DateTime(2026, 11, 1),
        daysRemaining: 19,
      );
      expect(dueSummary(vi, remaining, item), 'Còn 19 ngày (01/11/2026)');
      expect(dueSummary(en, remaining, item), '19 days left (Nov 1, 2026)');

      expect(
        dueSummary(
          vi,
          DueStatus(
            type: RecurrenceType.byTime,
            nextDueDate: DateTime(2026, 10, 13),
            daysRemaining: 0,
          ),
          item,
        ),
        'Tới hạn hôm nay',
      );

      final overdue = DueStatus(
        type: RecurrenceType.byTime,
        nextDueDate: DateTime(2026, 10, 1),
        daysRemaining: -12,
      );
      expect(dueSummary(vi, overdue, item), 'Quá hạn 12 ngày');
      expect(dueSummary(en, overdue, item), 'Overdue by 12 days');
    });

    test('English plurals use the singular for 1', () {
      expect(
        dueSummary(
          en,
          DueStatus(
            type: RecurrenceType.byTime,
            nextDueDate: DateTime(2026, 10, 14),
            daysRemaining: 1,
          ),
          item,
        ),
        '1 day left (Oct 14, 2026)',
      );
      expect(
        dueSummary(
          en,
          DueStatus(
            type: RecurrenceType.byTime,
            nextDueDate: DateTime(2026, 10, 12),
            daysRemaining: -1,
          ),
          item,
        ),
        'Overdue by 1 day',
      );
    });

    test('once says "Hết hạn" on the day', () {
      final today = DueStatus(
        type: RecurrenceType.once,
        nextDueDate: DateTime(2026, 10, 13),
        daysRemaining: 0,
      );
      expect(dueSummary(vi, today, item), 'Hết hạn hôm nay');
      expect(dueSummary(en, today, item), 'Expires today');
    });

    test('byValue: remaining, reached, overdue — with the item unit', () {
      expect(
        dueSummary(
          vi,
          const DueStatus(
            type: RecurrenceType.byValue,
            nextDueValue: 17000,
            remainingValue: 1500,
          ),
          item,
        ),
        'Còn 1.500 km (mốc 17.000 km)',
      );
      expect(
        dueSummary(
          en,
          const DueStatus(
            type: RecurrenceType.byValue,
            nextDueValue: 17000,
            remainingValue: 1500,
          ),
          item,
        ),
        '1,500 km left (due at 17,000 km)',
      );
      expect(
        dueSummary(
          vi,
          const DueStatus(
            type: RecurrenceType.byValue,
            nextDueValue: 17000,
            remainingValue: 0,
          ),
          item,
        ),
        'Tới mốc 17.000 km',
      );
      expect(
        dueSummary(
          vi,
          const DueStatus(
            type: RecurrenceType.byValue,
            nextDueValue: 17000,
            remainingValue: -250,
          ),
          item,
        ),
        'Quá mốc 250 km',
      );
    });

    test('missing data and none', () {
      expect(
        dueSummary(vi, const DueStatus.none(RecurrenceType.byTime), item),
        'Chưa đủ thông tin để tính mốc',
      );
      expect(
        dueSummary(vi, const DueStatus.none(RecurrenceType.byValue), item),
        'Chưa có chỉ số để tính mốc',
      );
      expect(
        dueSummary(vi, const DueStatus.none(RecurrenceType.none), item),
        'Không đặt mốc nhắc',
      );
    });
  });
}
