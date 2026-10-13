import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';

/// A soft-UI surface: raised (a light + dark `BoxShadow` pair suggesting
/// the surface pokes up from the background) or, when [pressed], a flat
/// tinted fill suggesting it's sunken in — used for the current selection.
class NeumorphicContainer extends StatelessWidget {
  const NeumorphicContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 16,
    this.pressed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: pressed
            ? Color.alphaBlend(
                t.darkShadow.withValues(alpha: 0.35),
                t.background,
              )
            : t.background,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: pressed
            ? null
            : [
                BoxShadow(
                  color: t.darkShadow,
                  offset: const Offset(4, 4),
                  blurRadius: 8,
                ),
                BoxShadow(
                  color: t.lightShadow,
                  offset: const Offset(-4, -4),
                  blurRadius: 8,
                ),
              ],
      ),
      child: child,
    );
  }
}
