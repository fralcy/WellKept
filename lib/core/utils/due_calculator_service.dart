import 'dart:math' as math;

import '../../models/maintenance_log.dart';
import '../../models/tracked_item.dart';
import '../models/due_status.dart';

/// Pure Dart: [TrackedItem] + its [MaintenanceLog]s → [DueStatus]. No
/// `BuildContext`, no Hive — [today] is injectable so tests are exact.
class DueCalculatorService {
  const DueCalculatorService();

  /// Scale used to put a one-off date (no interval to divide by) on the
  /// same urgency scale as recurring items — a warranty a year out ranks
  /// like a recurring item with its whole interval left.
  static const int _onceUrgencyScaleDays = 365;

  /// A `byValue` item counts as "due soon" within this fraction of its
  /// interval (e.g. the last 200 km of a 2,000 km interval).
  static const double _valueDueSoonFraction = 0.1;

  /// A `byValue` reading older than this many days is flagged stale.
  static const int staleReadingDays = 30;

  DueStatus calculate(
    TrackedItem item,
    List<MaintenanceLog> logs, {
    DateTime? today,
  }) {
    final day = _dateOnly(today ?? DateTime.now());
    final itemLogs = logs.where((l) => l.itemId == item.id).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final lastLog = itemLogs.isEmpty ? null : itemLogs.last;

    switch (item.recurrenceType) {
      case RecurrenceType.byTime:
        return _byTime(item, lastLog, day);
      case RecurrenceType.byValue:
        return _byValue(item, itemLogs, lastLog, day);
      case RecurrenceType.once:
        return _once(item, lastLog, day);
      case RecurrenceType.none:
        return DueStatus(type: item.recurrenceType, lastLogDate: lastLog?.date);
    }
  }

  DueStatus _byTime(TrackedItem item, MaintenanceLog? lastLog, DateTime day) {
    final interval = item.recurrenceIntervalDays;
    if (interval == null || interval <= 0) {
      return DueStatus.none(item.recurrenceType);
    }
    final anchor = _dateOnly(
      lastLog?.date ?? item.purchaseDate ?? item.createdAt,
    );
    final nextDue = _addDays(anchor, interval);
    final daysRemaining = _daysBetween(day, nextDue);
    return DueStatus(
      type: item.recurrenceType,
      nextDueDate: nextDue,
      daysRemaining: daysRemaining,
      lastLogDate: lastLog?.date,
      isOverdue: daysRemaining < 0,
      isDueSoon: daysRemaining <= item.reminderLeadDays,
      urgency: daysRemaining / interval,
    );
  }

  DueStatus _byValue(
    TrackedItem item,
    List<MaintenanceLog> sortedLogs,
    MaintenanceLog? lastLog,
    DateTime day,
  ) {
    final interval = item.recurrenceIntervalValue;
    if (interval == null || interval <= 0) {
      return DueStatus.none(item.recurrenceType);
    }
    // Baseline = reading at the latest log that recorded one; before any
    // such log, the item's own baseline (the reading entered when it was
    // added). Never [TrackedItem.currentValue] while a baseline exists —
    // otherwise updating today's reading would drag the due point along.
    final loggedValues = sortedLogs.map((l) => l.value).nonNulls;
    final baseline = loggedValues.isEmpty
        ? (item.baselineValue ?? item.currentValue)
        : loggedValues.last;
    if (baseline == null) return DueStatus.none(item.recurrenceType);

    // A log is entered after the fact, so it can be higher than the stored
    // reading (or vice versa) — trust whichever is further along.
    final current = math.max(item.currentValue ?? baseline, baseline);
    final nextDue = baseline + interval;
    final remaining = nextDue - current;

    // Latest moment a reading was entered: the item's own stamp or the
    // latest log that recorded one (items saved before the stamp existed
    // fall back to their creation date).
    final readingDates = [
      item.valueUpdatedAt ?? item.createdAt,
      for (final l in sortedLogs)
        if (l.value != null) l.date,
    ];
    final lastReading = readingDates.reduce((a, b) => a.isAfter(b) ? a : b);
    final daysSinceReading = math.max(0, _daysBetween(lastReading, day));

    return DueStatus(
      type: item.recurrenceType,
      nextDueValue: nextDue,
      remainingValue: remaining,
      currentValue: current,
      lastLogDate: lastLog?.date,
      daysSinceReading: daysSinceReading,
      isReadingStale: daysSinceReading > staleReadingDays,
      isOverdue: remaining < 0,
      isDueSoon: remaining <= interval * _valueDueSoonFraction,
      urgency: remaining / interval,
    );
  }

  DueStatus _once(TrackedItem item, MaintenanceLog? lastLog, DateTime day) {
    final expiry = item.expiryDate;
    if (expiry == null) return DueStatus.none(item.recurrenceType);
    final due = _dateOnly(expiry);
    final daysRemaining = _daysBetween(day, due);
    return DueStatus(
      type: item.recurrenceType,
      nextDueDate: due,
      daysRemaining: daysRemaining,
      lastLogDate: lastLog?.date,
      isOverdue: daysRemaining < 0,
      isDueSoon: daysRemaining <= item.reminderLeadDays,
      urgency: daysRemaining / _onceUrgencyScaleDays,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Calendar-day arithmetic via the DateTime constructor rather than
  /// `Duration(days: n)`, so a DST shift can't land on 23:00 the day before.
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);

  /// Whole calendar days from [from] to [to], computed in UTC so DST
  /// transitions don't produce off-by-one results.
  static int _daysBetween(DateTime from, DateTime to) {
    final a = DateTime.utc(from.year, from.month, from.day);
    final b = DateTime.utc(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }
}
