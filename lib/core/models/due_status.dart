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

  /// Date of the latest log, if any — for `byValue` the UI can warn when
  /// the reading hasn't been updated in a long time.
  final DateTime? lastLogDate;

  final bool isOverdue;
  final bool isDueSoon;

  /// Sort key, lower = more urgent: the fraction of the interval left
  /// (negative once overdue), so time- and value-based items compare on
  /// the same scale. [double.infinity] when there's no due point.
  final double urgency;

  bool get hasDuePoint => nextDueDate != null || nextDueValue != null;
}
