import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/neumorphic_themes.dart';
import '../../core/l10n/app_localizations.dart';
import '../../core/models/backup_data.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/tracked_item_provider.dart';
import '../../core/utils/backup_file_service.dart';
import '../../core/utils/backup_service.dart';
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
        const SizedBox(height: 20),
        Text(l10n.backupSection, style: sectionStyle),
        const SizedBox(height: 4),
        Text(l10n.backupHelper, style: TextStyle(color: t.textSecondary)),
        const SizedBox(height: 8),
        const _BackupButtons(),
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

class _BackupButtons extends StatelessWidget {
  const _BackupButtons();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        NeumorphicButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          onTap: () => _export(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.upload_file, size: 18),
              const SizedBox(width: 8),
              Text(l10n.exportBackup),
            ],
          ),
        ),
        NeumorphicButton(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          onTap: () => _import(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restore, size: 18),
              const SizedBox(width: 8),
              Text(l10n.importBackup),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<TrackedItemProvider>();
    final files = context.read<BackupFileService>();
    try {
      final bytes = await provider.exportBackup();
      final now = DateTime.now();
      final stamp =
          '${now.year}${_two(now.month)}${_two(now.day)}-'
          '${_two(now.hour)}${_two(now.minute)}';
      final saved = await files.save('wellkept-backup-$stamp.zip', bytes);
      if (saved) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.exportDone)));
      }
    } catch (e) {
      // Always surface I/O failures — never let one vanish silently
      // (ARCHITECTURE.md §9's file_picker lesson).
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed('$e'))));
    }
  }

  Future<void> _import(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final files = context.read<BackupFileService>();
    final BackupData data;
    try {
      final bytes = await files.pick();
      if (bytes == null) return;
      data = const BackupService().decode(bytes);
    } on BackupFormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(_formatErrorText(l10n, e.error))),
      );
      return;
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.backupFailed('$e'))));
      return;
    }
    if (!context.mounted) return;
    await _confirmRestore(context, data);
  }

  Future<void> _confirmRestore(BuildContext context, BackupData data) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final items = context.read<TrackedItemProvider>();
    final settings = context.read<SettingsProvider>();

    // The restore runs straight from the chosen button's handler (not
    // after awaiting the dialog's result) — same reasoning as deleting an
    // item in responsive_item_list_screen.dart.
    Future<void> restore(BuildContext dialogContext, bool replace) async {
      Navigator.of(dialogContext).pop();
      try {
        await items.importBackup(data, replace: replace);
        if (replace) settings.refresh();
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.restoreDone(data.items.length))),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.backupFailed('$e'))),
        );
      }
    }

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.restoreTitle),
        content: Text(
          '${l10n.restoreSummary(data.items.length, data.logs.length)}\n\n'
          '${l10n.restoreReplaceWarning}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => restore(dialogContext, true),
            child: Text(l10n.restoreReplace),
          ),
          TextButton(
            onPressed: () => restore(dialogContext, false),
            child: Text(l10n.restoreMerge),
          ),
        ],
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _formatErrorText(AppLocalizations l10n, BackupError error) {
    switch (error) {
      case BackupError.notABackup:
        return l10n.backupNotABackup;
      case BackupError.newerVersion:
        return l10n.backupNewerVersion;
      case BackupError.corrupt:
        return l10n.backupCorrupt;
    }
  }
}
