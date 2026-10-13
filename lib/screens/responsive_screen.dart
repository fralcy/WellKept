import 'package:flutter/material.dart';

/// Chooses between a desktop and mobile layout based on the *available
/// constraints*, never `Platform.isX` — so a desktop window resized small
/// still falls back to the mobile layout, and a phone rotated to landscape
/// can pick up the desktop layout too.
class ResponsiveScreen extends StatelessWidget {
  const ResponsiveScreen({
    super.key,
    required this.mobileBuilder,
    required this.desktopBuilder,
  });

  final WidgetBuilder mobileBuilder;
  final WidgetBuilder desktopBuilder;

  static bool isDesktop(BoxConstraints constraints) =>
      isDesktopSize(Size(constraints.maxWidth, constraints.maxHeight));

  /// Same breakpoint as [isDesktop], but from a plain [Size] — for call
  /// sites that only have `MediaQuery.sizeOf(context)` (e.g. deciding how
  /// to present a modal), not a `LayoutBuilder`'s constraints.
  static bool isDesktopSize(Size size) {
    return size.width >= 720 && size.width > size.height && size.height >= 600;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return isDesktop(constraints)
            ? desktopBuilder(context)
            : mobileBuilder(context);
      },
    );
  }
}
