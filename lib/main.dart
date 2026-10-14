import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/l10n/app_localizations.dart';
import 'core/providers/notification_provider.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/tracked_item_provider.dart';
import 'core/utils/backup_file_service.dart';
import 'core/utils/data_manager.dart';
import 'core/utils/notification_service_base.dart';
import 'core/utils/photo_picker_service.dart';
import 'screens/responsive_item_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await DataManager().initialize();
  } catch (e, st) {
    // A storage init failure shouldn't produce a blank crash screen — the
    // app still runs, just without persisted items/settings this session.
    debugPrint('DataManager init failed: $e\n$st');
  }

  runApp(const WellKeptApp());
}

class WellKeptApp extends StatelessWidget {
  const WellKeptApp({
    super.key,
    this.notificationService,
    this.photoPicker = const PhotoPickerService(),
    this.backupFiles = const BackupFileService(),
  });

  /// Overridable for tests; defaults to the platform implementation.
  final NotificationServiceBase? notificationService;
  final PhotoPickerService photoPicker;
  final BackupFileService backupFiles;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PhotoPickerService>.value(value: photoPicker),
        Provider<BackupFileService>.value(value: backupFiles),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TrackedItemProvider()),
        ChangeNotifierProvider(
          // Depends on the two providers above — read once here, the same
          // wiring pattern as DualCal's NotificationProvider.
          create: (context) {
            final provider = NotificationProvider(
              itemProvider: context.read<TrackedItemProvider>(),
              settingsProvider: context.read<SettingsProvider>(),
              notificationService: notificationService,
            );
            provider.init();
            return provider;
          },
          // Nothing watches it, so without this it would never be created.
          lazy: false,
        ),
      ],
      child: const _ThemedApp(),
    );
  }
}

/// Split out from [WellKeptApp] so `MaterialApp`'s theme can watch
/// [SettingsProvider] — a widget can't watch a provider declared by the
/// very [MultiProvider] wrapping it.
class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final themeConfig = settings.themeConfig;
    final brightness = ThemeData.estimateBrightnessForColor(
      themeConfig.background,
    );

    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeConfig.accent,
        brightness: brightness,
      ),
      scaffoldBackgroundColor: themeConfig.background,
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'WellKept',
      theme: baseTheme.copyWith(
        // Material 3's default type scale goes as small as ~11sp
        // (labelSmall) — floor every named style at 13px once here instead
        // of overriding every widget that uses bodySmall/labelSmall.
        textTheme: _withMinFontSize(baseTheme.textTheme, 13),
      ),
      locale: Locale(settings.languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ResponsiveItemListScreen(),
    );
  }
}

/// Returns a copy of [base] where every named style with a smaller
/// [TextStyle.fontSize] than [minSize] is raised to it, leaving styles that
/// are already at or above it untouched.
TextTheme _withMinFontSize(TextTheme base, double minSize) {
  TextStyle? clamped(TextStyle? style) {
    final size = style?.fontSize;
    if (style == null || size == null || size >= minSize) return style;
    return style.copyWith(fontSize: minSize);
  }

  return base.copyWith(
    displayLarge: clamped(base.displayLarge),
    displayMedium: clamped(base.displayMedium),
    displaySmall: clamped(base.displaySmall),
    headlineLarge: clamped(base.headlineLarge),
    headlineMedium: clamped(base.headlineMedium),
    headlineSmall: clamped(base.headlineSmall),
    titleLarge: clamped(base.titleLarge),
    titleMedium: clamped(base.titleMedium),
    titleSmall: clamped(base.titleSmall),
    bodyLarge: clamped(base.bodyLarge),
    bodyMedium: clamped(base.bodyMedium),
    bodySmall: clamped(base.bodySmall),
    labelLarge: clamped(base.labelLarge),
    labelMedium: clamped(base.labelMedium),
    labelSmall: clamped(base.labelSmall),
  );
}
