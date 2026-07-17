import 'package:flutter/material.dart';

import 'donut_gauge.dart';
import 'td_card.dart';
import 'td_tokens.dart';

/// A KPI card: an uppercase label, a big value (optionally inside a ring gauge)
/// and an optional status pill. Used in the reports/stats summary row.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.gaugeValue,
    this.accent,
    this.status,
    this.statusTone = StatTone.neutral,
  });

  final String label;
  final String value;
  final String? caption;

  /// When set (0..1), the value is shown inside a ring gauge; otherwise the
  /// value is rendered as a plain big number.
  final double? gaugeValue;
  final Color? accent;
  final String? status;
  final StatTone statusTone;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final accentColor = accent ?? context.cs.primary;
    final (pillBg, pillInk) = switch (statusTone) {
      StatTone.good => (td.goodBg, td.goodInk),
      StatTone.warn => (td.warnBg, td.warnInk),
      StatTone.crit => (td.critBg, td.critInk),
      StatTone.neutral => (td.infoBg, td.infoInk),
    };

    return TdCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w800,
              color: td.faint,
            ),
          ),
          const SizedBox(height: 12),
          if (gaugeValue != null)
            DonutGauge(
              value: gaugeValue!,
              color: accentColor,
              size: 96,
              center: _valueBlock(context, accentColor),
            )
          else
            SizedBox(height: 96, child: Center(child: _valueBlock(context, accentColor))),
          const SizedBox(height: 12),
          if (status != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
              decoration: BoxDecoration(
                color: pillBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status!,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: pillInk),
              ),
            ),
        ],
      ),
    );
  }

  Widget _valueBlock(BuildContext context, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: accentColor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              caption!,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: context.td.faint),
            ),
          ),
      ],
    );
  }
}

enum StatTone { neutral, good, warn, crit }
