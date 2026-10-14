import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/maintenance_log.dart';
import '../../models/tracked_item.dart';
import '../models/backup_data.dart';
import '../models/due_status.dart';
import '../utils/backup_service.dart';
import '../utils/data_manager.dart';
import '../utils/due_calculator_service.dart';
import '../utils/photo_storage_service.dart';

/// CRUD over [TrackedItem]s *and* their [MaintenanceLog]s via
/// [DataManager] — one provider for both, since every log change also
/// changes its item's due status; split only if that stops being true.
class TrackedItemProvider extends ChangeNotifier {
  TrackedItemProvider({
    DataManager? dataManager,
    DueCalculatorService? dueCalculator,
    PhotoStorageService? photoStorage,
  }) : _dataManager = dataManager ?? DataManager(),
       _dueCalculator = dueCalculator ?? const DueCalculatorService(),
       _photoStorage =
           photoStorage ??
           PhotoStorageService(dataManager: dataManager ?? DataManager()) {
    _reload();
  }

  final DataManager _dataManager;
  final DueCalculatorService _dueCalculator;
  final PhotoStorageService _photoStorage;

  Future<Uint8List?> loadPhoto(String photoId) => _photoStorage.load(photoId);

  /// Replaces the item's photo with [bytes] (or just removes it when
  /// null), deleting the previous photo's bytes so none are orphaned.
  Future<void> setItemPhoto(String itemId, Uint8List? bytes) async {
    final item = _dataManager.getItem(itemId);
    if (item == null) return;
    final oldPhotoId = item.photoId;
    final newPhotoId = bytes == null ? null : await _photoStorage.save(bytes);
    await _dataManager.saveItem(item.copyWith(photoId: () => newPhotoId));
    if (oldPhotoId != null) await _photoStorage.delete(oldPhotoId);
    _reload();
    notifyListeners();
  }

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

  /// Deletes the item together with its logs and every photo of either.
  Future<void> deleteItem(String id) async {
    final photoIds = [
      _dataManager.getItem(id)?.photoId,
      for (final log in _dataManager.getLogsForItem(id)) log.photoId,
    ].nonNulls;
    await _dataManager.deleteLogsForItem(id);
    for (final photoId in photoIds) {
      await _photoStorage.delete(photoId);
    }
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
      await _dataManager.saveItem(item.copyWith(currentValue: () => value));
    }

    _reload();
    notifyListeners();
    return log;
  }

  /// Records a new reading (e.g. today's odometer) without a maintenance
  /// log — moves the item toward its next due value and resets the
  /// "reading not updated in a while" warning. May also lower the reading,
  /// to correct a typo.
  Future<void> updateReading(String itemId, double value) async {
    final item = _dataManager.getItem(itemId);
    if (item == null) return;
    await _dataManager.saveItem(
      item.copyWith(
        currentValue: () => value,
        manualValue: () => value,
        valueUpdatedAt: () => DateTime.now(),
      ),
    );
    _reload();
    notifyListeners();
  }

  /// Saves an edited log (date, reading, note — not its photo, see
  /// [setLogPhoto]) and recomputes the item's current reading, which the
  /// old version of the log may have raised.
  Future<void> updateLog(MaintenanceLog updated) async {
    await _dataManager.saveLog(updated);
    await _recomputeReading(updated.itemId);
    _reload();
    notifyListeners();
  }

  /// Replaces the log's photo with [bytes] (or removes it when null) —
  /// same lifecycle as [setItemPhoto].
  Future<void> setLogPhoto(String logId, Uint8List? bytes) async {
    final log = _dataManager.getLog(logId);
    if (log == null) return;
    final oldPhotoId = log.photoId;
    final newPhotoId = bytes == null ? null : await _photoStorage.save(bytes);
    await _dataManager.saveLog(log.copyWith(photoId: () => newPhotoId));
    if (oldPhotoId != null) await _photoStorage.delete(oldPhotoId);
    _reload();
    notifyListeners();
  }

  Future<void> deleteLog(String id) async {
    final log = _dataManager.getLog(id);
    await _dataManager.deleteLog(id);
    if (log != null) {
      if (log.photoId != null) await _photoStorage.delete(log.photoId!);
      await _recomputeReading(log.itemId);
    }
    _reload();
    notifyListeners();
  }

  /// Everything (records + referenced photos) as backup-file bytes.
  Future<Uint8List> exportBackup({
    BackupService backupService = const BackupService(),
  }) async => backupService.encode(await _dataManager.collectBackup());

  /// Restores [data] (already decoded by [BackupService.decode]); see
  /// [DataManager.restoreBackup] for [replace] vs merge. Callers should
  /// also refresh SettingsProvider when replacing.
  Future<void> importBackup(BackupData data, {required bool replace}) async {
    await _dataManager.restoreBackup(data, replace: replace);
    _reload();
    notifyListeners();
  }

  /// Current reading = the highest of the last hand-entered reading and
  /// every log's reading. Run after a log is edited or deleted, so a
  /// reading that only came from that log doesn't linger.
  Future<void> _recomputeReading(String itemId) async {
    final item = _dataManager.getItem(itemId);
    if (item == null) return;
    final readings = [
      item.manualValue ?? item.baselineValue,
      for (final log in _dataManager.getLogsForItem(itemId)) log.value,
    ].nonNulls;
    if (readings.isEmpty) return;
    final recomputed = readings.reduce((a, b) => a > b ? a : b);
    if (recomputed != item.currentValue) {
      await _dataManager.saveItem(
        item.copyWith(currentValue: () => recomputed),
      );
    }
  }
}
