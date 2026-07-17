import 'package:flutter/material.dart';

import 'td_tokens.dart';

/// An uppercase eyebrow heading with an optional count chip and trailing
/// action — the section marker used across TimeDock screens.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.title, {
    super.key,
    this.count,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 2, 4, 10),
  });

  final String title;
  final int? count;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: td.faint,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: td.cardAlt,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: td.border),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: td.faint,
                ),
              ),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
