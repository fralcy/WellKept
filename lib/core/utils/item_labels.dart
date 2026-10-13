import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/tracked_item.dart';
import '../models/due_status.dart';

// Hard-coded Vietnamese display text for this milestone — moves into ARB
// files once the UI settles (see the l10n note in main.dart).

String categoryLabel(ItemCategory c) {
  switch (c) {
    case ItemCategory.vehicle:
      return 'Xe cộ';
    case ItemCategory.home:
      return 'Đồ gia dụng';
    case ItemCategory.warranty:
      return 'Bảo hành / hóa đơn';
    case ItemCategory.other:
      return 'Khác';
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

String recurrenceLabel(RecurrenceType r) {
  switch (r) {
    case RecurrenceType.byTime:
      return 'Định kỳ theo thời gian';
    case RecurrenceType.byValue:
      return 'Định kỳ theo chỉ số (km...)';
    case RecurrenceType.once:
      return 'Một lần (hết hạn bảo hành)';
    case RecurrenceType.none:
      return 'Không nhắc';
  }
}

final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');

/// Vietnamese grouping/decimal separators ("1.500,5"), at most one decimal.
final NumberFormat _valueFormat = NumberFormat('#,##0.#', 'vi');

String formatDate(DateTime d) => _dateFormat.format(d);

String formatValue(double v) => _valueFormat.format(v);

/// One-line "how far to the next due point" summary for the item list.
String dueSummary(DueStatus s, TrackedItem item) {
  switch (s.type) {
    case RecurrenceType.byTime:
    case RecurrenceType.once:
      final days = s.daysRemaining;
      if (days == null) return 'Chưa đủ thông tin để tính mốc';
      final verb = s.type == RecurrenceType.once ? 'Hết hạn' : 'Tới hạn';
      if (days < 0) return 'Quá hạn ${-days} ngày';
      if (days == 0) return '$verb hôm nay';
      return 'Còn $days ngày (${formatDate(s.nextDueDate!)})';
    case RecurrenceType.byValue:
      final remaining = s.remainingValue;
      if (remaining == null) return 'Chưa có chỉ số để tính mốc';
      final unit = item.valueUnit;
      if (remaining < 0) {
        return 'Quá mốc ${formatValue(-remaining)} $unit';
      }
      if (remaining == 0) {
        return 'Tới mốc ${formatValue(s.nextDueValue!)} $unit';
      }
      return 'Còn ${formatValue(remaining)} $unit '
          '(mốc ${formatValue(s.nextDueValue!)} $unit)';
    case RecurrenceType.none:
      return 'Không đặt mốc nhắc';
  }
}
