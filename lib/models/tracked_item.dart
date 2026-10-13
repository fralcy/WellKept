import 'package:hive/hive.dart';

part 'tracked_item.g.dart';

/// typeId registry (do not reuse or renumber once shipped):
/// 0 = TrackedItem, 1 = AppSettings, 2 = ItemCategory, 3 = RecurrenceType,
/// 4 = MaintenanceLog.

@HiveType(typeId: 2)
enum ItemCategory {
  @HiveField(0)
  vehicle,
  @HiveField(1)
  home,
  @HiveField(2)
  warranty,
  @HiveField(3)
  other,
}

/// How an item's next due point is derived (see `due_calculator_service.dart`):
/// `byTime` every N days from the latest log, `byValue` every N units of a
/// reading (e.g. km) from the latest log, `once` a single fixed date (a
/// warranty expiry), `none` no due point at all — just a record.
@HiveType(typeId: 3)
enum RecurrenceType {
  @HiveField(0)
  byTime,
  @HiveField(1)
  byValue,
  @HiveField(2)
  once,
  @HiveField(3)
  none,
}

/// A thing the user keeps track of — a vehicle, a home appliance, or a
/// receipt/warranty. The next due point is never stored here: it's
/// computed at runtime from this item plus its [MaintenanceLog]s, so
/// editing an old log can never leave a stale `nextDueDate` behind.
@HiveType(typeId: 0)
class TrackedItem extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  ItemCategory category;

  /// Key into DataManager's photo lazy box — bytes are never stored in
  /// this record, so opening the items box stays cheap however many
  /// photos the user has.
  @HiveField(3)
  String? photoId;

  /// Also the anchor a `byTime` item counts from until it has a log.
  @HiveField(4)
  DateTime? purchaseDate;

  @HiveField(5)
  RecurrenceType recurrenceType;

  /// Used when [recurrenceType] is `byTime`.
  @HiveField(6)
  int? recurrenceIntervalDays;

  /// Used when [recurrenceType] is `byValue`, e.g. 2000 (km).
  @HiveField(7)
  double? recurrenceIntervalValue;

  /// Latest known reading (e.g. odometer), raised by each new log.
  @HiveField(8)
  double? currentValue;

  /// Used when [recurrenceType] is `once` (e.g. warranty end).
  @HiveField(9)
  DateTime? expiryDate;

  @HiveField(10)
  int reminderLeadDays;

  /// Free-form: part numbers, the shop's phone number...
  @HiveField(11)
  String notes;

  /// Display unit for [currentValue]/[recurrenceIntervalValue].
  @HiveField(12)
  String valueUnit;

  @HiveField(13)
  DateTime createdAt;

  @HiveField(14)
  DateTime updatedAt;

  TrackedItem({
    required this.id,
    required this.name,
    this.category = ItemCategory.other,
    this.photoId,
    this.purchaseDate,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceIntervalDays,
    this.recurrenceIntervalValue,
    this.currentValue,
    this.expiryDate,
    this.reminderLeadDays = 7,
    this.notes = '',
    this.valueUnit = 'km',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory TrackedItem.create({
    required String id,
    required String name,
    ItemCategory category = ItemCategory.other,
    String? photoId,
    DateTime? purchaseDate,
    RecurrenceType recurrenceType = RecurrenceType.none,
    int? recurrenceIntervalDays,
    double? recurrenceIntervalValue,
    double? currentValue,
    DateTime? expiryDate,
    int reminderLeadDays = 7,
    String notes = '',
    String valueUnit = 'km',
  }) {
    final now = DateTime.now();
    return TrackedItem(
      id: id,
      name: name,
      category: category,
      photoId: photoId,
      purchaseDate: purchaseDate,
      recurrenceType: recurrenceType,
      recurrenceIntervalDays: recurrenceIntervalDays,
      recurrenceIntervalValue: recurrenceIntervalValue,
      currentValue: currentValue,
      expiryDate: expiryDate,
      reminderLeadDays: reminderLeadDays,
      notes: notes,
      valueUnit: valueUnit,
      createdAt: now,
      updatedAt: now,
    );
  }

  TrackedItem copyWith({
    String? name,
    ItemCategory? category,
    String? photoId,
    DateTime? purchaseDate,
    RecurrenceType? recurrenceType,
    int? recurrenceIntervalDays,
    double? recurrenceIntervalValue,
    double? currentValue,
    DateTime? expiryDate,
    int? reminderLeadDays,
    String? notes,
    String? valueUnit,
  }) {
    return TrackedItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      photoId: photoId ?? this.photoId,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceIntervalDays:
          recurrenceIntervalDays ?? this.recurrenceIntervalDays,
      recurrenceIntervalValue:
          recurrenceIntervalValue ?? this.recurrenceIntervalValue,
      currentValue: currentValue ?? this.currentValue,
      expiryDate: expiryDate ?? this.expiryDate,
      reminderLeadDays: reminderLeadDays ?? this.reminderLeadDays,
      notes: notes ?? this.notes,
      valueUnit: valueUnit ?? this.valueUnit,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
