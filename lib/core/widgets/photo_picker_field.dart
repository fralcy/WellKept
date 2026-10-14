import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';
import '../utils/photo_picker_service.dart';
import 'item_photo.dart';

/// Preview + take/pick/remove buttons for one photo in a form. Controlled:
/// the form keeps [changed]/[pickedBytes] and saves on submit; until the
/// user touches it, the stored photo ([storedPhotoId]) is shown untouched.
class PhotoPickerField extends StatelessWidget {
  const PhotoPickerField({
    super.key,
    required this.storedPhotoId,
    required this.changed,
    required this.pickedBytes,
    required this.onChanged,
  });

  final String? storedPhotoId;

  /// Whether the user picked or removed a photo in this form session.
  final bool changed;

  /// The picked photo when [changed]; null there means "removed".
  final Uint8List? pickedBytes;

  /// Called with the new bytes, or null when the photo is removed.
  final ValueChanged<Uint8List?> onChanged;

  static const double _size = 72;

  Future<void> _pick(BuildContext context, PhotoSource source) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await context.read<PhotoPickerService>().pick(source);
      if (bytes != null) onChanged(bytes);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.photoFailed('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;
    final l10n = AppLocalizations.of(context)!;
    final placeholder = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.darkShadow),
      ),
      child: Icon(Icons.image_outlined, color: t.textSecondary),
    );

    final Widget preview;
    final bool hasPhoto;
    if (changed) {
      hasPhoto = pickedBytes != null;
      preview = hasPhoto
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                pickedBytes!,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
              ),
            )
          : placeholder;
    } else {
      hasPhoto = storedPhotoId != null;
      preview = hasPhoto
          ? ItemPhoto(
              photoId: storedPhotoId!,
              size: _size,
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
                  onPressed: () => _pick(context, PhotoSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(l10n.takePhoto),
                ),
              TextButton.icon(
                onPressed: () => _pick(context, PhotoSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(kIsWeb ? l10n.addPhoto : l10n.pickPhoto),
              ),
              if (hasPhoto)
                TextButton.icon(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.removePhoto),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
