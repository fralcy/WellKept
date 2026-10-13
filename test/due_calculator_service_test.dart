import 'package:flutter_test/flutter_test.dart';

import 'package:well_kept/core/utils/due_calculator_service.dart';
import 'package:well_kept/models/maintenance_log.dart';
import 'package:well_kept/models/tracked_item.dart';

void main() {
  const calc = DueCalculatorService();
  final today = DateTime(2026, 10, 13);

  MaintenanceLog log(String itemId, DateTime date, {double? value}) =>
      MaintenanceLog(
        id: '${itemId}_$date',
        itemId: itemId,
        date: date,
        value: value,
      );

  group('byTime', () {
    final item = TrackedItem(
      id: 'ac',
      name: 'Máy lạnh',
      recurrenceType: RecurrenceType.byTime,
      recurrenceIntervalDays: 180,
      purchaseDate: DateTime(2026, 1, 1),
      reminderLeadDays: 7,
    );

    test('counts from the latest log, not the purchase date or log order', () {
      final s = calc.calculate(item, [
        log('ac', DateTime(2026, 8, 1)),
        log('ac', DateTime(2026, 2, 1)),
      ], today: today);
      expect(s.nextDueDate, DateTime(2027, 1, 28));
      expect(s.daysRemaining, 107);
      expect(s.isOverdue, isFalse);
      expect(s.isDueSoon, isFalse);
      expect(s.lastLogDate, DateTime(2026, 8, 1));
    });

    test('falls back to the purchase date when there is no log', () {
      final s = calc.calculate(item, const [], today: today);
      expect(s.nextDueDate, DateTime(2026, 6, 30));
      expect(s.daysRemaining, -105);
      expect(s.isOverdue, isTrue);
      expect(s.urgency, lessThan(0));
    });

    test(
      'is due soon within reminderLeadDays, and ignores other items\' logs',
      () {
        final s = calc.calculate(item, [
          log('ac', DateTime(2026, 4, 20)), // due 2026-10-17, in 4 days
          log('other', DateTime(2026, 10, 1)),
        ], today: today);
        expect(s.daysRemaining, 4);
        expect(s.isDueSoon, isTrue);
        expect(s.isOverdue, isFalse);
      },
    );

    test('due today is not overdue', () {
      final s = calc.calculate(item, [
        log('ac', DateTime(2026, 4, 16)),
      ], today: today);
      expect(s.daysRemaining, 0);
      expect(s.isOverdue, isFalse);
      expect(s.isDueSoon, isTrue);
    });
  });

  group('byValue', () {
    final bike = TrackedItem(
      id: 'bike',
      name: 'Xe máy',
      recurrenceType: RecurrenceType.byValue,
      recurrenceIntervalValue: 2000,
      currentValue: 15000,
    );

    test('without logs, counts from the reading entered at creation', () {
      final s = calc.calculate(bike, const [], today: today);
      expect(s.nextDueValue, 17000);
      expect(s.remainingValue, 2000);
      expect(s.isOverdue, isFalse);
      expect(s.isDueSoon, isFalse);
    });

    test('counts from the latest log that recorded a reading', () {
      final s = calc.calculate(bike.copyWith(currentValue: () => 16500), [
        log('bike', DateTime(2026, 9, 1), value: 15200),
        log('bike', DateTime(2026, 9, 20)), // no reading
      ], today: today);
      expect(s.nextDueValue, 17200);
      expect(s.currentValue, 16500);
      expect(s.remainingValue, 700);
      expect(s.lastLogDate, DateTime(2026, 9, 20));
    });

    test('is due soon in the last 10% of the interval, overdue past it', () {
      final soon = calc.calculate(bike.copyWith(currentValue: () => 16850), [
        log('bike', DateTime(2026, 9, 1), value: 15000),
      ], today: today);
      expect(soon.remainingValue, 150);
      expect(soon.isDueSoon, isTrue);
      expect(soon.isOverdue, isFalse);

      final overdue = calc.calculate(bike.copyWith(currentValue: () => 17300), [
        log('bike', DateTime(2026, 9, 1), value: 15000),
      ], today: today);
      expect(overdue.remainingValue, -300);
      expect(overdue.isOverdue, isTrue);
      expect(overdue.urgency, lessThan(0));
    });

    test('has no due point without any reading', () {
      final s = calc.calculate(
        TrackedItem(
          id: 'x',
          name: 'x',
          recurrenceType: RecurrenceType.byValue,
          recurrenceIntervalValue: 2000,
        ),
        const [],
        today: today,
      );
      expect(s.hasDuePoint, isFalse);
      expect(s.urgency, double.infinity);
    });

    group('stale reading', () {
      final added = TrackedItem(
        id: 'car',
        name: 'Ô tô',
        recurrenceType: RecurrenceType.byValue,
        recurrenceIntervalValue: 5000,
        currentValue: 40000,
        createdAt: DateTime(2026, 8, 1),
        valueUpdatedAt: DateTime(2026, 8, 1),
      );

      test('counts days since the reading was entered', () {
        final fresh = calc.calculate(
          added,
          const [],
          today: DateTime(2026, 8, 31),
        );
        expect(fresh.daysSinceReading, 30);
        expect(fresh.isReadingStale, isFalse);

        final stale = calc.calculate(
          added,
          const [],
          today: DateTime(2026, 9, 1),
        );
        expect(stale.daysSinceReading, 31);
        expect(stale.isReadingStale, isTrue);
      });

      test('a newer log with a reading refreshes it, one without does not', () {
        final withReading = calc.calculate(added, [
          log('car', DateTime(2026, 10, 1), value: 42000),
        ], today: today);
        expect(withReading.daysSinceReading, 12);
        expect(withReading.isReadingStale, isFalse);

        final withoutReading = calc.calculate(added, [
          log('car', DateTime(2026, 10, 1)),
        ], today: today);
        expect(withoutReading.daysSinceReading, 73);
        expect(withoutReading.isReadingStale, isTrue);
      });

      test('a newer valueUpdatedAt (update reading) refreshes it', () {
        final s = calc.calculate(
          added.copyWith(valueUpdatedAt: () => DateTime(2026, 10, 10)),
          [log('car', DateTime(2026, 8, 15), value: 40500)],
          today: today,
        );
        expect(s.daysSinceReading, 3);
        expect(s.isReadingStale, isFalse);
      });

      test(
        'falls back to createdAt for items saved before the stamp existed',
        () {
          final s = calc.calculate(
            added.copyWith(valueUpdatedAt: () => null),
            const [],
            today: today,
          );
          expect(s.daysSinceReading, 73);
        },
      );

      test('never applies to time-based items', () {
        final s = calc.calculate(
          TrackedItem(
            id: 't',
            name: 't',
            recurrenceType: RecurrenceType.byTime,
            recurrenceIntervalDays: 30,
            createdAt: DateTime(2020),
          ),
          const [],
          today: today,
        );
        expect(s.isReadingStale, isFalse);
        expect(s.daysSinceReading, isNull);
      });
    });
  });

  group('once', () {
    final warranty = TrackedItem(
      id: 'tv',
      name: 'Tivi',
      category: ItemCategory.warranty,
      recurrenceType: RecurrenceType.once,
      expiryDate: DateTime(2026, 11, 1),
      reminderLeadDays: 30,
    );

    test('counts down to the expiry date, ignoring logs', () {
      final s = calc.calculate(warranty, [
        log('tv', DateTime(2026, 10, 1)),
      ], today: today);
      expect(s.nextDueDate, DateTime(2026, 11, 1));
      expect(s.daysRemaining, 19);
      expect(s.isDueSoon, isTrue);
      expect(s.isOverdue, isFalse);
    });

    test('is overdue (expired) after the expiry date', () {
      final s = calc.calculate(
        warranty,
        const [],
        today: DateTime(2026, 11, 3, 18, 30),
      );
      expect(s.daysRemaining, -2);
      expect(s.isOverdue, isTrue);
    });
  });

  test('none has no due point and sorts last', () {
    final s = calc.calculate(
      TrackedItem(id: 'n', name: 'n'),
      const [],
      today: today,
    );
    expect(s.hasDuePoint, isFalse);
    expect(s.isOverdue, isFalse);
    expect(s.urgency, double.infinity);
  });
}
