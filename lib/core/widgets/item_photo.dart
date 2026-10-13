import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tracked_item_provider.dart';

/// Shows a stored photo, loaded lazily from the photo box by [photoId];
/// [placeholder] is shown while loading and if the photo is missing.
class ItemPhoto extends StatefulWidget {
  const ItemPhoto({
    super.key,
    required this.photoId,
    required this.size,
    required this.placeholder,
    this.borderRadius = 12,
  });

  final String photoId;
  final double size;
  final Widget placeholder;
  final double borderRadius;

  @override
  State<ItemPhoto> createState() => _ItemPhotoState();
}

class _ItemPhotoState extends State<ItemPhoto> {
  late Future<Uint8List?> _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ItemPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoId != widget.photoId) _load();
  }

  /// Kept in state rather than started in build, so rebuilding the list
  /// (any provider change) doesn't re-read every photo from storage.
  void _load() {
    _bytes = context.read<TrackedItemProvider>().loadPhoto(widget.photoId);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: FutureBuilder<Uint8List?>(
        future: _bytes,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) return widget.placeholder;
          return ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) => widget.placeholder,
            ),
          );
        },
      ),
    );
  }
}
