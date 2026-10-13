import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/tracked_item.dart';
import '../l10n/app_localizations.dart';
import '../models/due_status.dart';

// Display helpers shared by the UI and NotificationProvider — every one
// takes the AppLocalizations to render in, so the same code serves both
// a widget's `AppLocalizations.of(context)` and a non-widget
// `lookupAppLocalizations(locale)`.

String categoryLabel(AppLocalizations l10n, ItemCategory c) {
  switch (c) {
    case ItemCategory.vehicle:
      return l10n.categoryVehicle;
    case ItemCategory.home:
      return l10n.categoryHome;
    case ItemCategory.warranty:
      return l10n.categoryWarranty;
    case ItemCategory.other:
      return l10n.categoryOther;
  }
}

IconData categoryIcon(ItemCategory c) {
  switch (c) {
    case ItemCategory.vehicle:
      return Icons.two_wheeler;
    case ItemCategory.home:
      return Icons.kitchen;
    case ItemCategory.warranty:
      return Icons.receipt_long;
    case ItemCategory.other:
      return Icons.inventory_2_outlined;
  }
}

String recurrenceLabel(AppLocalizations l10n, RecurrenceType r) {
  switch (r) {
    case RecurrenceType.byTime:
      return l10n.recurrenceByTime;
    case RecurrenceType.byValue:
      return l10n.recurrenceByValue;
    case RecurrenceType.once:
      return l10n.recurrenceOnce;
    case RecurrenceType.none:
      return l10n.recurrenceNone;
  }
}

/// "05/03/2026" in Vietnamese, "Mar 5, 2026" in English (where a numeric
/// date would be ambiguous between US and day-first readers). Both use
/// en_US — the only date-symbol data intl ships pre-initialized — so this
/// also works outside the widget tree (e.g. notification text), before or
/// without flutter_localizations loading any other locale's data.
String formatDate(AppLocalizations l10n, DateTime d) =>
    l10n.localeName.startsWith('vi')
    ? DateFormat('dd/MM/yyyy', 'en_US').format(d)
    : DateFormat.yMMMd('en_US').format(d);

/// Locale grouping/decimal separators ("1.500,5" / "1,500.5"), at most one
/// decimal.
String formatValue(AppLocalizations l10n, double v) =>
    NumberFormat('#,##0.#', l10n.localeName).format(v);

/// One-line "how far to the next due point" summary for the item list.
String dueSummary(AppLocalizations l10n, DueStatus s, TrackedItem item) {
  switch (s.type) {
    case RecurrenceType.byTime:
    case RecurrenceType.once:
      final days = s.daysRemaining;
      if (days == null) return l10n.dueMissingInfo;
      if (days < 0) return l10n.dueOverdueDays(-days);
      if (days == 0) {
        return s.type == RecurrenceType.once
            ? l10n.expiresToday
            : l10n.dueToday;
      }
      return l10n.dueInDays(days, formatDate(l10n, s.nextDueDate!));
    case RecurrenceType.byValue:
      final remaining = s.remainingValue;
      if (remaining == null) return l10n.dueMissingReading;
      final unit = item.valueUnit;
      final target = formatValue(l10n, s.nextDueValue!);
      if (remaining < 0) {
        return l10n.dueOverValue(formatValue(l10n, -remaining), unit);
      }
      if (remaining == 0) return l10n.dueAtValue(target, unit);
      return l10n.dueInValue(formatValue(l10n, remaining), target, unit);
    case RecurrenceType.none:
      return l10n.dueNone;
  }
}

/// Warning shown under [dueSummary] when a `byValue` reading is stale, or
/// null when there's nothing to warn about.
String? staleReadingWarning(AppLocalizations l10n, DueStatus s) {
  if (!s.isReadingStale) return null;
  return l10n.staleReading(s.daysSinceReading!);
}
