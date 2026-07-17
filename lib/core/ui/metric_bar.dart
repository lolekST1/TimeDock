import 'package:flutter/material.dart';

import 'td_tokens.dart';

/// A horizontal progress bar with an optional leading label and trailing value,
/// used in the ranked report/stat lists. [value] is 0..1.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.value,
    required this.color,
    this.label,
    this.trailing,
    this.trailingColor,
  });

  final double value;
  final Color color;
  final String? label;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Row(
      children: [
        if (label != null)
          SizedBox(
            width: 62,
            child: Text(
              label!.toUpperCase(),
              style: TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
                color: td.faint,
              ),
            ),
          ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value.clamp(0, 1).toDouble(),
              minHeight: 9,
              backgroundColor: td.track,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Text(
              trailing!,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: trailingColor ?? context.cs.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
