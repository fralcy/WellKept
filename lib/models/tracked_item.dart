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

  /// When [currentValue] was last entered (at creation, via "update
  /// reading", or by a log) — drives the "reading not updated in a while"
  /// warning, since the app can't read an odometer itself.
  @HiveField(15)
  DateTime? valueUpdatedAt;

  /// `byValue`: reading at the last maintenance *before* any log existed
  /// (entered when the item is added). Kept apart from [currentValue] so
  /// updating today's reading moves the item toward its due point instead
  /// of dragging the due point along with it. Logs with a reading take
  /// over as the baseline once they exist.
  @HiveField(16)
  double? baselineValue;

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
    this.valueUpdatedAt,
    this.baselineValue,
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
    double? baselineValue,
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
      valueUpdatedAt: currentValue == null ? null : now,
      // The reading entered when adding an item is the one at its last
      // maintenance, so it doubles as the baseline unless told otherwise.
      baselineValue: baselineValue ?? currentValue,
    );
  }

  /// Nullable fields take a getter so they can be cleared, not just set:
  /// `copyWith(expiryDate: () => null)` removes the expiry date, while
  /// omitting the argument keeps the current value.
  TrackedItem copyWith({
    String? name,
    ItemCategory? category,
    String? Function()? photoId,
    DateTime? Function()? purchaseDate,
    RecurrenceType? recurrenceType,
    int? Function()? recurrenceIntervalDays,
    double? Function()? recurrenceIntervalValue,
    double? Function()? currentValue,
    DateTime? Function()? expiryDate,
    int? reminderLeadDays,
    String? notes,
    String? valueUnit,
    DateTime? Function()? valueUpdatedAt,
    double? Function()? baselineValue,
  }) {
    return TrackedItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      photoId: photoId != null ? photoId() : this.photoId,
      purchaseDate: purchaseDate != null ? purchaseDate() : this.purchaseDate,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceIntervalDays: recurrenceIntervalDays != null
          ? recurrenceIntervalDays()
          : this.recurrenceIntervalDays,
      recurrenceIntervalValue: recurrenceIntervalValue != null
          ? recurrenceIntervalValue()
          : this.recurrenceIntervalValue,
      currentValue: currentValue != null ? currentValue() : this.currentValue,
      expiryDate: expiryDate != null ? expiryDate() : this.expiryDate,
      reminderLeadDays: reminderLeadDays ?? this.reminderLeadDays,
      notes: notes ?? this.notes,
      valueUnit: valueUnit ?? this.valueUnit,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      valueUpdatedAt: valueUpdatedAt != null
          ? valueUpdatedAt()
          : this.valueUpdatedAt,
      baselineValue: baselineValue != null
          ? baselineValue()
          : this.baselineValue,
    );
  }
}
