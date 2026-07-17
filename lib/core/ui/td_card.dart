import 'package:flutter/material.dart';

import 'td_tokens.dart';

/// A soft-cornered surface with a hairline border and gentle elevation — the
/// base container of the TimeDock design language. Optionally tappable.
class TdCard extends StatelessWidget {
  const TdCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.onLongPress,
    this.color,
    this.radius = 16,
    this.clip = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final double radius;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: td.border),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: td.cardShadow,
      ),
      child: Material(
        color: color ?? td.card,
        shape: shape,
        clipBehavior: clip || onTap != null ? Clip.antiAlias : Clip.none,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
