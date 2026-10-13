import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/neumorphic_themes.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/widgets/neumorphic_button.dart';
import 'adaptive_modal.dart';

/// Language, theme and reminder time. Every change applies (and persists)
/// immediately — there's no save button.
Future<void> showSettingsModal(BuildContext context) {
  return showAdaptiveModal(context, child: const _SettingsSheet());
}

/// Languages offered, by their own name so they're findable whatever the
/// current UI language is.
const _languages = {'vi': 'Tiếng Việt', 'en': 'English'};

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final t = settings.themeConfig;
    final l10n = AppLocalizations.of(context)!;
    final sectionStyle = TextStyle(
      fontWeight: FontWeight.w600,
      color: t.textPrimary,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.settings,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: t.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.language, style: sectionStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final entry in _languages.entries)
              NeumorphicButton(
                selected: settings.languageCode == entry.key,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                onTap: () => settings.setLanguageCode(entry.key),
                child: Text(entry.value),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.theme, style: sectionStyle),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final NeumorphicThemeConfig theme in neumorphicThemePresets)
              Tooltip(
                message: theme.label,
                child: NeumorphicButton(
                  selected: settings.themeId == theme.id,
                  padding: const EdgeInsets.all(8),
                  onTap: () => settings.setThemeId(theme.id),
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.background,
                    child: CircleAvatar(
                      radius: 7,
                      backgroundColor: theme.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text(l10n.reminderTime, style: sectionStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            NeumorphicButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onTap: () => _pickReminderTime(context, settings),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    TimeOfDay(
                      hour: settings.reminderHour,
                      minute: settings.reminderMinute,
                    ).format(context),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          kIsWeb ? l10n.remindersWebNote : l10n.reminderTimeHelper,
          style: TextStyle(color: t.textSecondary),
        ),
      ],
    );
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.reminderHour,
        minute: settings.reminderMinute,
      ),
    );
    if (picked != null) {
      await settings.setReminderTime(picked.hour, picked.minute);
    }
  }
}
