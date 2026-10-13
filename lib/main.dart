import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/providers/settings_provider.dart';
import 'core/providers/tracked_item_provider.dart';
import 'core/utils/data_manager.dart';
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
  const WellKeptApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => TrackedItemProvider()),
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
      // UI text is hard-coded Vietnamese this milestone (ARB l10n comes
      // later); these delegates still localize Material widgets such as
      // the date picker.
      locale: Locale(settings.languageCode),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('vi'), Locale('en')],
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
