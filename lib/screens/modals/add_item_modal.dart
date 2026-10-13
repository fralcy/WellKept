import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_localizations.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/providers/tracked_item_provider.dart';
import '../../core/utils/item_labels.dart';
import '../../core/utils/photo_picker_service.dart';
import '../../core/widgets/item_photo.dart';
import '../../core/widgets/neumorphic_button.dart';
import '../../models/tracked_item.dart';
import 'adaptive_modal.dart';

/// Form to add a new [TrackedItem].
Future<void> showAddItemModal(BuildContext context) {
  return showAdaptiveModal(context, child: const _ItemForm());
}

/// The same form, prefilled to edit an existing [item].
Future<void> showEditItemModal(BuildContext context, TrackedItem item) {
  return showAdaptiveModal(context, child: _ItemForm(item: item));
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({this.item});

  /// Null when adding.
  final TrackedItem? item;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _intervalDaysController = TextEditingController(text: '180');
  final _intervalValueController = TextEditingController(text: '2000');
  final _currentValueController = TextEditingController();
  final _unitController = TextEditingController(text: 'km');
  final _leadDaysController = TextEditingController(text: '7');
  final _notesController = TextEditingController();

  ItemCategory _category = ItemCategory.vehicle;
  RecurrenceType _recurrence = RecurrenceType.byTime;
  DateTime _startDate = DateTime.now();
  DateTime? _expiryDate;
  bool _saving = false;

  /// Photo picked in this form session; with [_photoChanged] false the
  /// item's stored photo (if any) is shown and kept untouched.
  Uint8List? _photoBytes;
  bool _photoChanged = false;

  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item == null) return;
    _nameController.text = item.name;
    if (item.recurrenceIntervalDays != null) {
      _intervalDaysController.text = '${item.recurrenceIntervalDays}';
    }
    if (item.recurrenceIntervalValue != null) {
      _intervalValueController.text = _formatInput(
        item.recurrenceIntervalValue!,
      );
    }
    if (item.currentValue != null) {
      _currentValueController.text = _formatInput(item.currentValue!);
    }
    _unitController.text = item.valueUnit;
    _leadDaysController.text = '${item.reminderLeadDays}';
    _notesController.text = item.notes;
    _category = item.category;
    _recurrence = item.recurrenceType;
    _startDate = item.purchaseDate ?? item.createdAt;
    _expiryDate = item.expiryDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalDaysController.dispose();
    _intervalValueController.dispose();
    _currentValueController.dispose();
    _unitController.dispose();
    _leadDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime initial) {
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1990),
      lastDate: DateTime(2100),
    );
  }

  Future<void> _pickPhoto(AppLocalizations l10n, PhotoSource source) async {
    try {
      final bytes = await context.read<PhotoPickerService>().pick(source);
      if (bytes == null || !mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoChanged = true;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.photoFailed('$e'))));
    }
  }

  void _removePhoto() => setState(() {
    _photoBytes = null;
    _photoChanged = true;
  });

  Future<void> _save(AppLocalizations l10n) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    // Fields that don't apply to the chosen recurrence type are saved as
    // null — on edit, that clears whatever an earlier type had set.
    final name = _nameController.text.trim();
    final intervalDays = _recurrence == RecurrenceType.byTime
        ? int.parse(_intervalDaysController.text)
        : null;
    final intervalValue = _recurrence == RecurrenceType.byValue
        ? _parseDouble(_intervalValueController.text)
        : null;
    final currentValue = _recurrence == RecurrenceType.byValue
        ? _parseDouble(_currentValueController.text)
        : null;
    final expiryDate = _recurrence == RecurrenceType.once ? _expiryDate : null;
    final leadDays = int.tryParse(_leadDaysController.text) ?? 7;
    final notes = _notesController.text.trim();
    final unit = _unitController.text.trim().isEmpty
        ? 'km'
        : _unitController.text.trim();

    try {
      final provider = context.read<TrackedItemProvider>();
      final original = widget.item;
      final String itemId;
      if (original == null) {
        final created = await provider.addItem(
          name: name,
          category: _category,
          purchaseDate: _startDate,
          recurrenceType: _recurrence,
          recurrenceIntervalDays: intervalDays,
          recurrenceIntervalValue: intervalValue,
          currentValue: currentValue,
          expiryDate: expiryDate,
          reminderLeadDays: leadDays,
          notes: notes,
          valueUnit: unit,
        );
        itemId = created.id;
      } else {
        final readingChanged = currentValue != original.currentValue;
        await provider.updateItem(
          original.copyWith(
            name: name,
            category: _category,
            purchaseDate: () => _startDate,
            recurrenceType: _recurrence,
            recurrenceIntervalDays: () => intervalDays,
            recurrenceIntervalValue: () => intervalValue,
            currentValue: () => currentValue,
            expiryDate: () => expiryDate,
            reminderLeadDays: leadDays,
            notes: notes,
            valueUnit: unit,
            valueUpdatedAt: readingChanged && currentValue != null
                ? () => DateTime.now()
                : null,
            // Editing "current reading" never moves the baseline; one is
            // only seeded when the item becomes value-based for the first
            // time, and dropped when it stops being value-based.
            baselineValue: _recurrence != RecurrenceType.byValue
                ? () => null
                : original.baselineValue == null
                ? () => currentValue
                : null,
          ),
        );
        itemId = original.id;
      }
      if (_photoChanged) await provider.setItemPhoto(itemId, _photoBytes);
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

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEditing ? l10n.editItem : l10n.addItem,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _photoSection(l10n),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(labelText: l10n.itemName),
            textInputAction: TextInputAction.next,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? l10n.itemNameRequired : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<ItemCategory>(
            initialValue: _category,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.category),
            items: [
              for (final c in ItemCategory.values)
                DropdownMenuItem(value: c, child: Text(categoryLabel(l10n, c))),
            ],
            onChanged: (c) => setState(() {
              _category = c!;
              // A warranty is almost always a one-off expiry date.
              if (c == ItemCategory.warranty) {
                _recurrence = RecurrenceType.once;
              }
            }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<RecurrenceType>(
            key: ValueKey(_recurrence),
            initialValue: _recurrence,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.recurrence),
            items: [
              for (final r in RecurrenceType.values)
                DropdownMenuItem(
                  value: r,
                  child: Text(recurrenceLabel(l10n, r)),
                ),
            ],
            onChanged: (r) => setState(() => _recurrence = r!),
          ),
          const SizedBox(height: 12),
          ..._recurrenceFields(l10n),
          const SizedBox(height: 12),
          _DateField(
            label: _recurrence == RecurrenceType.byTime
                ? l10n.lastServiceOrStart
                : l10n.purchaseDate,
            value: _startDate,
            onTap: () async {
              final picked = await _pickDate(_startDate);
              if (picked != null) setState(() => _startDate = picked);
            },
          ),
          if (_recurrence == RecurrenceType.byTime ||
              _recurrence == RecurrenceType.once) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _leadDaysController,
              decoration: InputDecoration(labelText: l10n.reminderLeadDays),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _notesController,
            decoration: InputDecoration(labelText: l10n.itemNotes),
            minLines: 1,
            maxLines: 4,
          ),
          const SizedBox(height: 20),
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

  Widget _photoSection(AppLocalizations l10n) {
    final t = context.watch<SettingsProvider>().themeConfig;
    const size = 72.0;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.darkShadow),
      ),
      child: Icon(Icons.image_outlined, color: t.textSecondary),
    );
    final storedPhotoId = widget.item?.photoId;

    final Widget preview;
    final bool hasPhoto;
    if (_photoChanged) {
      hasPhoto = _photoBytes != null;
      preview = hasPhoto
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _photoBytes!,
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            )
          : placeholder;
    } else {
      hasPhoto = storedPhotoId != null;
      preview = hasPhoto
          ? ItemPhoto(
              photoId: storedPhotoId,
              size: size,
              placeholder: placeholder,
            )
          : placeholder;
    }

    return Row(
      children: [
        preview,
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              // A browser can't be asked for the camera directly; its file
              // dialog already offers the camera where the device has one.
              if (!kIsWeb)
                TextButton.icon(
                  onPressed: () => _pickPhoto(l10n, PhotoSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.takePhoto),
                ),
              TextButton.icon(
                onPressed: () => _pickPhoto(l10n, PhotoSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(kIsWeb ? l10n.addPhoto : l10n.pickPhoto),
              ),
              if (hasPhoto)
                TextButton.icon(
                  onPressed: _removePhoto,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.removePhoto),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _recurrenceFields(AppLocalizations l10n) {
    switch (_recurrence) {
      case RecurrenceType.byTime:
        return [
          TextFormField(
            controller: _intervalDaysController,
            decoration: InputDecoration(
              labelText: l10n.intervalDays,
              helperText: l10n.intervalDaysHelper,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                ? l10n.intervalDaysInvalid
                : null,
          ),
        ];
      case RecurrenceType.byValue:
        return [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _intervalValueController,
                  decoration: InputDecoration(labelText: l10n.intervalValue),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => (_parseDouble(v) ?? 0) <= 0
                      ? l10n.positiveNumberRequired
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _unitController,
                  decoration: InputDecoration(labelText: l10n.valueUnit),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _currentValueController,
            decoration: InputDecoration(
              labelText: _isEditing
                  ? l10n.currentReading
                  : l10n.readingAtLastService,
              helperText: _isEditing ? null : l10n.readingAtLastServiceHelper,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                _parseDouble(v) == null ? l10n.readingRequired : null,
          ),
        ];
      case RecurrenceType.once:
        return [
          FormField<DateTime>(
            validator: (_) =>
                _expiryDate == null ? l10n.expiryDateRequired : null,
            builder: (field) => _DateField(
              label: l10n.expiryDate,
              value: _expiryDate,
              errorText: field.errorText,
              onTap: () async {
                final picked = await _pickDate(
                  _expiryDate ??
                      DateTime(
                        _startDate.year + 1,
                        _startDate.month,
                        _startDate.day,
                      ),
                );
                if (picked != null) {
                  setState(() => _expiryDate = picked);
                  field.didChange(picked);
                }
              },
            ),
          ),
        ];
      case RecurrenceType.none:
        return const [];
    }
  }
}

/// Accepts both "1500.5" and "1500,5".
double? _parseDouble(String? v) =>
    double.tryParse((v ?? '').trim().replaceAll(',', '.'));

/// Prefill text for a numeric field: "15000", not "15000.0".
String _formatInput(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value == null ? l10n.pickDate : formatDate(l10n, value!)),
      ),
    );
  }
}
