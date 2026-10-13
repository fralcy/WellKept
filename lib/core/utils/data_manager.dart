import 'dart:typed_data';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/app_settings.dart';
import '../../models/maintenance_log.dart';
import '../../models/tracked_item.dart';

/// Singleton owner of every Hive box in the app. `initialize()` runs once
/// in `main()`: registers all TypeAdapters, opens boxes, and seeds default
/// data if a box is empty. UI code never touches Hive directly — it goes
/// through a Provider, which goes through this class.
class DataManager {
  DataManager._internal();
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;

  static const String _itemsBoxName = 'tracked_items';
  static const String _logsBoxName = 'maintenance_logs';
  static const String _settingsBoxName = 'app_settings';
  static const String _photosBoxName = 'photo_bytes';
  static const String _settingsKey = 'settings';

  late Box<TrackedItem> _itemsBox;
  late Box<MaintenanceLog> _logsBox;
  late Box<AppSettings> _settingsBox;

  /// A *lazy* box: only keys are loaded at open time, each photo's bytes
  /// are read on `get()` — so photos never bloat app startup the way a
  /// regular box (fully loaded into RAM on open) would. Works the same on
  /// mobile and web, no platform-specific file storage needed.
  late LazyBox<Uint8List> _photosBox;

  bool _initialized = false;

  /// [hivePath] lets tests point Hive at a plain temp directory via
  /// `Hive.init` instead of `Hive.initFlutter` (which needs the
  /// path_provider platform channel, unavailable in plain `flutter test`).
  Future<void> initialize({String? hivePath}) async {
    if (_initialized) return;

    if (hivePath != null) {
      Hive.init(hivePath);
    } else {
      await Hive.initFlutter();
    }

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(TrackedItemAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AppSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ItemCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(RecurrenceTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(MaintenanceLogAdapter());
    }

    _itemsBox = await Hive.openBox<TrackedItem>(_itemsBoxName);
    _logsBox = await Hive.openBox<MaintenanceLog>(_logsBoxName);
    _settingsBox = await Hive.openBox<AppSettings>(_settingsBoxName);
    _photosBox = await Hive.openLazyBox<Uint8List>(_photosBoxName);

    if (_settingsBox.get(_settingsKey) == null) {
      await _settingsBox.put(_settingsKey, AppSettings.initial());
    }

    _initialized = true;
  }

  // ---------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------

  AppSettings get settings => _settingsBox.get(_settingsKey)!;

  Future<void> saveSettings(AppSettings settings) async {
    await _settingsBox.put(_settingsKey, settings);
  }

  // ---------------------------------------------------------------------
  // Tracked items
  // ---------------------------------------------------------------------

  List<TrackedItem> getAllItems() => _itemsBox.values.toList();

  TrackedItem? getItem(String id) => _itemsBox.get(id);

  Future<void> saveItem(TrackedItem item) async {
    await _itemsBox.put(item.id, item);
  }

  Future<void> deleteItem(String id) async {
    await _itemsBox.delete(id);
  }

  // ---------------------------------------------------------------------
  // Maintenance logs
  // ---------------------------------------------------------------------

  List<MaintenanceLog> getAllLogs() => _logsBox.values.toList();

  List<MaintenanceLog> getLogsForItem(String itemId) =>
      _logsBox.values.where((l) => l.itemId == itemId).toList();

  Future<void> saveLog(MaintenanceLog log) async {
    await _logsBox.put(log.id, log);
  }

  Future<void> deleteLog(String id) async {
    await _logsBox.delete(id);
  }

  Future<void> deleteLogsForItem(String itemId) async {
    final ids = _logsBox.values
        .where((l) => l.itemId == itemId)
        .map((l) => l.id)
        .toList();
    await _logsBox.deleteAll(ids);
  }

  // ---------------------------------------------------------------------
  // Photos (lazy box — see [_photosBox])
  // ---------------------------------------------------------------------

  Future<Uint8List?> getPhotoBytes(String id) => _photosBox.get(id);

  Future<void> savePhotoBytes(String id, Uint8List bytes) async {
    await _photosBox.put(id, bytes);
  }

  Future<void> deletePhotoBytes(String id) async {
    await _photosBox.delete(id);
  }

  /// Resets all app data (items, logs, photos + settings back to defaults).
  Future<void> clearAll() async {
    await _itemsBox.clear();
    await _logsBox.clear();
    await _photosBox.clear();
    await _settingsBox.clear();
    await _settingsBox.put(_settingsKey, AppSettings.initial());
  }
}
