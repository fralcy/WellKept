import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../constants/neumorphic_themes.dart';
import '../utils/data_manager.dart';

/// Wraps the single persisted [AppSettings] record. Also doubles as the
/// theme provider — the state is small and single-record, so a separate
/// ThemeProvider would just be an extra provider for one derived field.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({DataManager? dataManager})
    : _dataManager = dataManager ?? DataManager();

  final DataManager _dataManager;

  AppSettings get _settings => _dataManager.settings;

  String get languageCode => _settings.languageCode;
  String get themeId => _settings.themeId;
  NeumorphicThemeConfig get themeConfig => themeById(themeId);
  int get reminderHour => _settings.reminderHour;
  int get reminderMinute => _settings.reminderMinute;

  Future<void> setReminderTime(int hour, int minute) async {
    await _dataManager.saveSettings(
      _settings.copyWith(reminderHour: hour, reminderMinute: minute),
    );
    notifyListeners();
  }

  Future<void> setThemeId(String id) async {
    await _dataManager.saveSettings(_settings.copyWith(themeId: id));
    notifyListeners();
  }

  Future<void> setLanguageCode(String code) async {
    await _dataManager.saveSettings(_settings.copyWith(languageCode: code));
    notifyListeners();
  }

  /// Re-reads from [DataManager] and notifies — used after a backup import
  /// overwrites settings directly.
  void refresh() => notifyListeners();
}
