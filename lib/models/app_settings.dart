import 'package:hive/hive.dart';

part 'app_settings.g.dart';

/// Singleton settings record — DataManager keeps exactly one instance of
/// this in its Hive box, created via [AppSettings.initial] on first launch.
@HiveType(typeId: 1)
class AppSettings extends HiveObject {
  @HiveField(0)
  String languageCode;

  @HiveField(1)
  String themeId;

  /// Local time of day (0-23) every reminder fires at. Records saved
  /// before this field existed read back the 08:00 default.
  @HiveField(2, defaultValue: 8)
  int reminderHour;

  @HiveField(3, defaultValue: 0)
  int reminderMinute;

  AppSettings({
    required this.languageCode,
    required this.themeId,
    this.reminderHour = 8,
    this.reminderMinute = 0,
  });

  factory AppSettings.initial() {
    return AppSettings(languageCode: 'vi', themeId: 'sky');
  }

  AppSettings copyWith({
    String? languageCode,
    String? themeId,
    int? reminderHour,
    int? reminderMinute,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      themeId: themeId ?? this.themeId,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
    );
  }
}
