import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/tracked_item_provider.dart';
import '../../core/utils/item_labels.dart';
import '../../core/widgets/item_photo.dart';
import '../../core/widgets/neumorphic_button.dart';
import '../../core/widgets/photo_picker_field.dart';
import '../../models/maintenance_log.dart';
import '../../models/tracked_item.dart';
import 'adaptive_modal.dart';

/// Records a maintenance log for [item], and lists its past logs below the
/// form (newest first). Tapping a past log loads it into the same form to
/// edit it, rather than stacking a second modal.
Future<void> showAddLogModal(BuildContext context, TrackedItem item) {
  return showAdaptiveModal(context, child: _LogSheet(itemId: item.id));
}

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.itemId});

  /// Looked up live from the provider, so the header/history reflect a
  /// log saved from this very sheet.
  final String itemId;

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  Uint8List? _photoBytes;
  bool _photoChanged = false;

  /// The log being edited, or null when adding a new one.
  MaintenanceLog? _editing;

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _startEditing(MaintenanceLog log) {
    setState(() {
      _editing = log;
      _date = log.date;
      _valueController.text = log.value == null ? '' : _formatInput(log.value!);
      _noteController.text = log.note;
      _photoBytes = null;
      _photoChanged = false;
    });
  }

  void _resetToAdding() {
    setState(() {
      _editing = null;
      _date = DateTime.now();
      _valueController.clear();
      _noteController.clear();
      _photoBytes = null;
      _photoChanged = false;
    });
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<TrackedItemProvider>();
    final value = _parseDouble(_valueController.text);
    final note = _noteController.text.trim();
    try {
      final editing = _editing;
      final String logId;
      if (editing == null) {
        final log = await provider.addLog(
          itemId: widget.itemId,
          date: _date,
          value: value,
          note: note,
        );
        logId = log.id;
      } else {
        await provider.updateLog(
          editing.copyWith(date: _date, value: () => value, note: note),
        );
        logId = editing.id;
      }
      if (_photoChanged) await provider.setLogPhoto(logId, _photoBytes);
      if (!mounted) return;
      if (editing == null) {
        Navigator.of(context).pop();
      } else {
        setState(() => _saving = false);
        _resetToAdding();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.saveFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;
    final l10n = AppLocalizations.of(context)!;
    final provider = context.watch<TrackedItemProvider>();
    final item = provider.items.where((i) => i.id == widget.itemId).firstOrNull;
    if (item == null) return const SizedBox.shrink();

    final status = provider.statusFor(item);
    final logs = provider.logsFor(item.id);
    final tracksValue = item.recurrenceType == RecurrenceType.byValue;
    final editing = _editing;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            editing == null
                ? l10n.logTitle(item.name)
                : l10n.editLogTitle(formatDate(l10n, editing.date)),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dueSummary(l10n, status, item),
            style: TextStyle(color: t.textSecondary),
          ),
          if (item.notes.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(item.notes, style: TextStyle(color: t.textSecondary)),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(1990),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.logDate,
                suffixIcon: const Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(formatDate(l10n, _date)),
            ),
          ),
          if (tracksValue) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: l10n.logReading(item.valueUnit),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) =>
                  _parseDouble(v) == null ? l10n.readingRequired : null,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(labelText: l10n.logNote),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          PhotoPickerField(
            // Keyed by the log being edited, so switching logs drops the
            // previous one's preview.
            key: ValueKey(editing?.id),
            storedPhotoId: editing?.photoId,
            changed: _photoChanged,
            pickedBytes: _photoBytes,
            onChanged: (bytes) => setState(() {
              _photoBytes = bytes;
              _photoChanged = true;
            }),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (editing != null) ...[
                TextButton(
                  onPressed: _resetToAdding,
                  child: Text(l10n.cancelEdit),
                ),
                const SizedBox(width: 8),
              ],
              NeumorphicButton(
                onTap: () => _save(l10n),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Text(l10n.save),
              ),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              l10n.logHistory,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: t.textPrimary,
              ),
            ),
            for (final log in logs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                selected: log.id == editing?.id,
                onTap: () => _startEditing(log),
                leading: log.photoId == null
                    ? null
                    : ItemPhoto(
                        photoId: log.photoId!,
                        size: 40,
                        borderRadius: 8,
                        placeholder: const Icon(Icons.image_outlined),
                      ),
                title: Text(
                  [
                    formatDate(l10n, log.date),
                    if (log.value != null)
                      '${formatValue(l10n, log.value!)} ${item.valueUnit}',
                  ].join(' · '),
                ),
                subtitle: log.note.isEmpty ? null : Text(log.note),
                trailing: IconButton(
                  tooltip: l10n.deleteLog,
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    if (log.id == editing?.id) _resetToAdding();
                    provider.deleteLog(log.id);
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Accepts both "1500.5" and "1500,5".
double? _parseDouble(String? v) =>
    double.tryParse((v ?? '').trim().replaceAll(',', '.'));

/// Prefill text for a numeric field: "15000", not "15000.0".
String _formatInput(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
