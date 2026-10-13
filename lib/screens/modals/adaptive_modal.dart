import 'package:flutter/material.dart';

import '../../core/widgets/neumorphic_container.dart';
import '../responsive_screen.dart';

/// Shows [child] as a dialog on desktop-sized screens and as a bottom sheet
/// otherwise — the one presentation rule every `showXModal` shares.
Future<T?> showAdaptiveModal<T>(
  BuildContext context, {
  required Widget child,
  double maxWidth = 480,
}) {
  final isDesktop = ResponsiveScreen.isDesktopSize(MediaQuery.sizeOf(context));

  if (isDesktop) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: ModalFrame(child: child),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // The bottom padding lets the sheet grow when the keyboard appears, and
    // the height cap guarantees a real scrollable viewport to scroll a
    // focused field into above the keyboard.
    builder: (context) {
      final media = MediaQuery.of(context);
      return Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.9),
          child: ModalFrame(child: child),
        ),
      );
    },
  );
}

/// The raised, scrollable card every modal's content sits in.
class ModalFrame extends StatelessWidget {
  const ModalFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        child: NeumorphicContainer(
          padding: const EdgeInsets.all(20),
          borderRadius: 24,
          child: SingleChildScrollView(child: child),
        ),
      ),
    );
  }
}
