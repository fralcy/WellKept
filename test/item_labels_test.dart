import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/models/due_status.dart';
import 'package:well_kept/core/utils/item_labels.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  final item = TrackedItem(id: 'i', name: 'i', valueUnit: 'km');

  test('formatValue uses Vietnamese separators, at most one decimal', () {
    expect(formatValue(2000), '2.000');
    expect(formatValue(1500.5), '1.500,5');
    expect(formatValue(12.34), '12,3');
  });

  test('formatDate is dd/MM/yyyy', () {
    expect(formatDate(DateTime(2026, 3, 5)), '05/03/2026');
  });

  group('dueSummary', () {
    test('byTime: remaining, today, overdue', () {
      expect(
        dueSummary(
          DueStatus(
            type: RecurrenceType.byTime,
            nextDueDate: DateTime(2026, 11, 1),
            daysRemaining: 19,
          ),
          item,
        ),
        'Còn 19 ngày (01/11/2026)',
      );
      expect(
        dueSummary(
          DueStatus(
            type: RecurrenceType.byTime,
            nextDueDate: DateTime(2026, 10, 13),
            daysRemaining: 0,
          ),
          item,
        ),
        'Tới hạn hôm nay',
      );
      expect(
        dueSummary(
          DueStatus(
            type: RecurrenceType.byTime,
            nextDueDate: DateTime(2026, 10, 1),
            daysRemaining: -12,
          ),
          item,
        ),
        'Quá hạn 12 ngày',
      );
    });

    test('once says "Hết hạn" on the day', () {
      expect(
        dueSummary(
          DueStatus(
            type: RecurrenceType.once,
            nextDueDate: DateTime(2026, 10, 13),
            daysRemaining: 0,
          ),
          item,
        ),
        'Hết hạn hôm nay',
      );
    });

    test('byValue: remaining, reached, overdue — with the item unit', () {
      expect(
        dueSummary(
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
        dueSummary(const DueStatus.none(RecurrenceType.byTime), item),
        'Chưa đủ thông tin để tính mốc',
      );
      expect(
        dueSummary(const DueStatus.none(RecurrenceType.byValue), item),
        'Chưa có chỉ số để tính mốc',
      );
      expect(
        dueSummary(const DueStatus.none(RecurrenceType.none), item),
        'Không đặt mốc nhắc',
      );
    });
  });
}
