import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/maintenance_log.dart';
import '../../models/tracked_item.dart';
import '../models/due_status.dart';
import '../utils/data_manager.dart';
import '../utils/due_calculator_service.dart';

/// CRUD over [TrackedItem]s *and* their [MaintenanceLog]s via
/// [DataManager] — one provider for both, since every log change also
/// changes its item's due status; split only if that stops being true.
class TrackedItemProvider extends ChangeNotifier {
  TrackedItemProvider({
    DataManager? dataManager,
    DueCalculatorService? dueCalculator,
  }) : _dataManager = dataManager ?? DataManager(),
       _dueCalculator = dueCalculator ?? const DueCalculatorService() {
    _reload();
  }

  final DataManager _dataManager;
  final DueCalculatorService _dueCalculator;

  List<TrackedItem> _items = [];
  Map<String, List<MaintenanceLog>> _logsByItem = {};

  List<TrackedItem> get items => List.unmodifiable(_items);

  void _reload() {
    _items = _dataManager.getAllItems();
    _logsByItem = {};
    for (final log in _dataManager.getAllLogs()) {
      _logsByItem.putIfAbsent(log.itemId, () => []).add(log);
    }
  }

  /// Force-reload from [DataManager] — used after a backup import.
  void refresh() {
    _reload();
    notifyListeners();
  }

  /// Newest first.
  List<MaintenanceLog> logsFor(String itemId) =>
      List.of(_logsByItem[itemId] ?? const <MaintenanceLog>[])
        ..sort((a, b) => b.date.compareTo(a.date));

  DueStatus statusFor(TrackedItem item, {DateTime? today}) => _dueCalculator
      .calculate(item, _logsByItem[item.id] ?? const [], today: today);

  /// Items sorted most-urgent first (overdue, then least of their
  /// interval left); items without a due point go last, by name.
  List<TrackedItem> itemsByUrgency({DateTime? today}) {
    final statuses = {
      for (final item in _items) item.id: statusFor(item, today: today),
    };
    return List.of(_items)..sort((a, b) {
      final byUrgency = statuses[a.id]!.urgency.compareTo(
        statuses[b.id]!.urgency,
      );
      return byUrgency != 0 ? byUrgency : a.name.compareTo(b.name);
    });
  }

  Future<TrackedItem> addItem({
    required String name,
    ItemCategory category = ItemCategory.other,
    DateTime? purchaseDate,
    RecurrenceType recurrenceType = RecurrenceType.none,
    int? recurrenceIntervalDays,
    double? recurrenceIntervalValue,
    double? currentValue,
    DateTime? expiryDate,
    int reminderLeadDays = 7,
    String notes = '',
    String valueUnit = 'km',
  }) async {
    final item = TrackedItem.create(
      id: const Uuid().v4(),
      name: name,
      category: category,
      purchaseDate: purchaseDate,
      recurrenceType: recurrenceType,
      recurrenceIntervalDays: recurrenceIntervalDays,
      recurrenceIntervalValue: recurrenceIntervalValue,
      currentValue: currentValue,
      expiryDate: expiryDate,
      reminderLeadDays: reminderLeadDays,
      notes: notes,
      valueUnit: valueUnit,
    );
    await _dataManager.saveItem(item);
    _reload();
    notifyListeners();
    return item;
  }

  Future<void> updateItem(TrackedItem updated) async {
    await _dataManager.saveItem(updated);
    _reload();
    notifyListeners();
  }

  /// Deletes the item together with its logs and photo.
  Future<void> deleteItem(String id) async {
    final photoId = _dataManager.getItem(id)?.photoId;
    await _dataManager.deleteLogsForItem(id);
    if (photoId != null) await _dataManager.deletePhotoBytes(photoId);
    await _dataManager.deleteItem(id);
    _reload();
    notifyListeners();
  }

  /// Records a maintenance log; a reading higher than the item's current
  /// one also advances [TrackedItem.currentValue].
  Future<MaintenanceLog> addLog({
    required String itemId,
    required DateTime date,
    double? value,
    String note = '',
  }) async {
    final log = MaintenanceLog.create(
      id: const Uuid().v4(),
      itemId: itemId,
      date: date,
      value: value,
      note: note,
    );
    await _dataManager.saveLog(log);

    final item = _dataManager.getItem(itemId);
    if (item != null &&
        value != null &&
        (item.currentValue == null || value > item.currentValue!)) {
      await _dataManager.saveItem(item.copyWith(currentValue: value));
    }

    _reload();
    notifyListeners();
    return log;
  }

  Future<void> deleteLog(String id) async {
    await _dataManager.deleteLog(id);
    _reload();
    notifyListeners();
  }
}
