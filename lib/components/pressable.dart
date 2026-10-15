import 'package:flutter/material.dart';

import '../core/logic/motion.dart';

/// The pressable surface behind every button, chip and list row: it shrinks slightly and dims while
/// pressed (HIG: immediate, subtle feedback). With Reduce Motion only the dimming remains — an
/// opacity change is not motion.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onPressed,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
    this.button = true,
    this.selected,
    this.checked,
    this.dimWhenDisabled = true,
    this.excludeChildSemantics = true,
    this.hitSlop = 0,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? semanticLabel;
  final String? semanticHint;
  final bool button;
  final bool? selected;
  final bool? checked;

  /// Draw a disabled control at 60 % opacity. Off for rows that are simply not tappable.
  final bool dimWhenDisabled;

  /// The label replaces the children's own semantics (one element per control, as in the RN app).
  final bool excludeChildSemantics;

  /// Extra invisible touch area around the child (HIG 44 pt target for small controls).
  final double hitSlop;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null || widget.onLongPress != null;

  void _set(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final base = !_enabled && widget.dimWhenDisabled ? 0.6 : 1.0;
    final scale = _pressed && !reduceMotion ? pressScale : 1.0;
    Widget child = AnimatedScale(
      scale: scale,
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: base * (_pressed ? 0.8 : 1),
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
    if (widget.hitSlop > 0) child = Padding(padding: EdgeInsets.all(widget.hitSlop), child: child);
    return Semantics(
      button: widget.button && _enabled,
      enabled: _enabled,
      selected: widget.selected,
      checked: widget.checked,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      excludeSemantics: widget.excludeChildSemantics && widget.semanticLabel != null,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _set(true) : null,
        onTapUp: _enabled ? (_) => _set(false) : null,
        onTapCancel: () => _set(false),
        onTap: widget.onPressed,
        onLongPress: widget.onLongPress,
        child: child,
      ),
    );
  }
}
