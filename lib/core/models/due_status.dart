import '../../models/tracked_item.dart';

/// Derived "how far to the next due point" for one [TrackedItem] — computed
/// on demand by `DueCalculatorService`, never persisted.
class DueStatus {
  const DueStatus({
    required this.type,
    this.nextDueDate,
    this.daysRemaining,
    this.nextDueValue,
    this.remainingValue,
    this.currentValue,
    this.lastLogDate,
    this.daysSinceReading,
    this.isReadingStale = false,
    this.isOverdue = false,
    this.isDueSoon = false,
    this.urgency = double.infinity,
  });

  /// An item with no due point (`RecurrenceType.none`, or missing the
  /// fields its recurrence type needs).
  const DueStatus.none(RecurrenceType type) : this(type: type);

  final RecurrenceType type;

  /// `byTime` / `once`.
  final DateTime? nextDueDate;

  /// Whole calendar days from today to [nextDueDate]; negative = overdue.
  final int? daysRemaining;

  /// `byValue`: reading at which the next maintenance is due.
  final double? nextDueValue;

  /// `byValue`: [nextDueValue] minus [currentValue]; negative = overdue.
  final double? remainingValue;

  /// `byValue`: best-known current reading.
  final double? currentValue;

  /// Date of the latest log, if any.
  final DateTime? lastLogDate;

  /// `byValue`: whole days since the reading was last entered (via a log,
  /// "update reading", or when the item was added).
  final int? daysSinceReading;

  /// `byValue`: the reading is old enough that [remainingValue] may be
  /// well off — the app can't read an odometer, so it asks for an update.
  final bool isReadingStale;

  final bool isOverdue;
  final bool isDueSoon;

  /// Sort key, lower = more urgent: the fraction of the interval left
  /// (negative once overdue), so time- and value-based items compare on
  /// the same scale. [double.infinity] when there's no due point.
  final double urgency;

  bool get hasDuePoint => nextDueDate != null || nextDueValue != null;
}
