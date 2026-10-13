import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/tracked_item_provider.dart';
import '../../core/utils/item_labels.dart';
import '../../core/widgets/neumorphic_button.dart';
import '../../models/tracked_item.dart';
import 'adaptive_modal.dart';

/// Enters today's reading (e.g. odometer) for a `byValue` [item] without
/// recording a maintenance log.
Future<void> showUpdateReadingModal(BuildContext context, TrackedItem item) {
  return showAdaptiveModal(
    context,
    maxWidth: 380,
    child: _UpdateReadingForm(item: item),
  );
}

class _UpdateReadingForm extends StatefulWidget {
  const _UpdateReadingForm({required this.item});

  final TrackedItem item;

  @override
  State<_UpdateReadingForm> createState() => _UpdateReadingFormState();
}

class _UpdateReadingFormState extends State<_UpdateReadingForm> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _save(AppLocalizations l10n) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await context.read<TrackedItemProvider>().updateReading(
        widget.item.id,
        _parseDouble(_valueController.text)!,
      );
      if (mounted) Navigator.of(context).pop();
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
    final item = widget.item;
    final current = item.currentValue;

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.updateReadingTitle(item.name),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
          if (current != null) ...[
            const SizedBox(height: 4),
            Text(
              l10n.storedReading(formatValue(l10n, current), item.valueUnit),
              style: TextStyle(color: t.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _valueController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.currentReadingWithUnit(item.valueUnit),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                _parseDouble(v) == null ? l10n.readingRequired : null,
            onFieldSubmitted: (_) => _save(l10n),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: NeumorphicButton(
              onTap: () => _save(l10n),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

/// Accepts both "1500.5" and "1500,5".
double? _parseDouble(String? v) =>
    double.tryParse((v ?? '').trim().replaceAll(',', '.'));
