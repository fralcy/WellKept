import 'package:hive/hive.dart';

part 'maintenance_log.g.dart';

/// One maintenance event for a [TrackedItem] (see `tracked_item.dart` for
/// the typeId registry). The latest log is what the next due point is
/// counted from.
@HiveType(typeId: 4)
class MaintenanceLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String itemId;

  @HiveField(2)
  DateTime date;

  /// Reading at the time of maintenance (e.g. odometer), if relevant.
  @HiveField(3)
  double? value;

  @HiveField(4)
  String note;

  @HiveField(5)
  DateTime createdAt;

  /// Key into DataManager's photo lazy box (e.g. the shop's receipt).
  @HiveField(6)
  String? photoId;

  MaintenanceLog({
    required this.id,
    required this.itemId,
    required this.date,
    this.value,
    this.note = '',
    DateTime? createdAt,
    this.photoId,
  }) : createdAt = createdAt ?? DateTime.now();

  factory MaintenanceLog.create({
    required String id,
    required String itemId,
    required DateTime date,
    double? value,
    String note = '',
  }) {
    return MaintenanceLog(
      id: id,
      itemId: itemId,
      date: date,
      value: value,
      note: note,
      createdAt: DateTime.now(),
    );
  }

  /// Nullable fields take a getter so they can be cleared — see
  /// `TrackedItem.copyWith`.
  MaintenanceLog copyWith({
    DateTime? date,
    double? Function()? value,
    String? note,
    String? Function()? photoId,
  }) {
    return MaintenanceLog(
      id: id,
      itemId: itemId,
      date: date ?? this.date,
      value: value != null ? value() : this.value,
      note: note ?? this.note,
      createdAt: createdAt,
      photoId: photoId != null ? photoId() : this.photoId,
    );
  }
}
