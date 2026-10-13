import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import 'neumorphic_container.dart';

/// A tappable [NeumorphicContainer] — raised at rest, flat/tinted while
/// pressed, matching soft-UI button conventions.
class NeumorphicButton extends StatefulWidget {
  const NeumorphicButton({
    super.key,
    required this.child,
    required this.onTap,
    this.padding = const EdgeInsets.all(10),
    this.borderRadius = 14,
    this.selected = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  /// Forces the pressed/inset look even when not actively being tapped —
  /// used to show a persistent selection (e.g. the active theme swatch).
  final bool selected;

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _pressing = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsProvider>().themeConfig;

    return FocusableActionDetector(
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      mouseCursor: SystemMouseCursors.click,
      // Bound locally (closer to this widget than any screen-level
      // Shortcuts) so a focused button always activates on Enter/Space
      // itself first, instead of a broader shortcut intercepting the key.
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressing = true),
        onTapCancel: () => setState(() => _pressing = false),
        onTapUp: (_) => setState(() => _pressing = false),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius + 2),
            border: _focused ? Border.all(color: t.accent, width: 2) : null,
          ),
          child: NeumorphicContainer(
            padding: widget.padding,
            borderRadius: widget.borderRadius,
            pressed: widget.selected || _pressing,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: t.textPrimary),
              child: IconTheme.merge(
                data: IconThemeData(color: t.textPrimary),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
