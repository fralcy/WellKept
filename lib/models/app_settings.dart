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

  AppSettings({required this.languageCode, required this.themeId});

  factory AppSettings.initial() {
    return AppSettings(languageCode: 'vi', themeId: 'sky');
  }

  AppSettings copyWith({String? languageCode, String? themeId}) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      themeId: themeId ?? this.themeId,
    );
  }
}
