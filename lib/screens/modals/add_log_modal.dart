import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/providers/tracked_item_provider.dart';
import '../../core/utils/item_labels.dart';
import '../../core/widgets/neumorphic_button.dart';
import '../../models/tracked_item.dart';
import 'adaptive_modal.dart';

/// Records a maintenance log for [item], and lists its past logs below the
/// form (newest first).
Future<void> showAddLogModal(BuildContext context, TrackedItem item) {
  return showAdaptiveModal(context, child: _AddLogForm(itemId: item.id));
}

class _AddLogForm extends StatefulWidget {
  const _AddLogForm({required this.itemId});

  /// Looked up live from the provider, so the header/history reflect a
  /// log saved from this very sheet.
  final String itemId;

  @override
  State<_AddLogForm> createState() => _AddLogFormState();
}

class _AddLogFormState extends State<_AddLogForm> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _valueController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<TrackedItemProvider>().addLog(
        itemId: widget.itemId,
        date: _date,
        value: _parseDouble(_valueController.text),
        note: _noteController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không lưu được: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;
    final provider = context.watch<TrackedItemProvider>();
    final item = provider.items.where((i) => i.id == widget.itemId).firstOrNull;
    if (item == null) return const SizedBox.shrink();

    final status = provider.statusFor(item);
    final logs = provider.logsFor(item.id);
    final tracksValue = item.recurrenceType == RecurrenceType.byValue;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ghi bảo trì: ${item.name}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dueSummary(status, item),
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
              decoration: const InputDecoration(
                labelText: 'Ngày bảo trì',
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(formatDate(_date)),
            ),
          ),
          if (tracksValue) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _valueController,
              decoration: InputDecoration(
                labelText: 'Chỉ số lúc bảo trì (${item.valueUnit})',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) =>
                  _parseDouble(v) == null ? 'Nhập chỉ số hiện tại' : null,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: NeumorphicButton(
              onTap: _save,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: const Text('Lưu'),
            ),
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Lịch sử bảo trì',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: t.textPrimary,
              ),
            ),
            for (final log in logs)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  [
                    formatDate(log.date),
                    if (log.value != null)
                      '${formatValue(log.value!)} ${item.valueUnit}',
                  ].join(' · '),
                ),
                subtitle: log.note.isEmpty ? null : Text(log.note),
                trailing: IconButton(
                  tooltip: 'Xóa log',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => provider.deleteLog(log.id),
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
