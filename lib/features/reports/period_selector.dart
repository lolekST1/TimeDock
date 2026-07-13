import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/report_range.dart';
import 'report_providers.dart';

/// Shared period control used by Reports and Statistics: a day/week/month/
/// custom segmented button plus prev/next navigation and a range label.
/// Selecting "custom" opens a date-range picker.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final range = ref.watch(reportRangeProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SegmentedButton<ReportPeriod>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ReportPeriod.day, label: Text('Dzień')),
              ButtonSegment(value: ReportPeriod.week, label: Text('Tydzień')),
              ButtonSegment(value: ReportPeriod.month, label: Text('Miesiąc')),
              ButtonSegment(
                  value: ReportPeriod.custom, icon: Icon(Icons.date_range)),
            ],
            selected: {period},
            onSelectionChanged: (s) => _onPeriod(context, ref, s.first),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shift(ref, period, -1),
            ),
            TextButton(
              onPressed: period == ReportPeriod.custom
                  ? () => _pickCustom(context, ref)
                  : null,
              child: Text(_rangeLabel(period, range),
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shift(ref, period, 1),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onPeriod(
      BuildContext context, WidgetRef ref, ReportPeriod period) async {
    if (period == ReportPeriod.custom) {
      final picked = await _pickCustom(context, ref);
      // Only switch to custom if the user actually chose a range.
      if (picked) ref.read(reportPeriodProvider.notifier).state = period;
    } else {
      ref.read(reportPeriodProvider.notifier).state = period;
    }
  }

  Future<bool> _pickCustom(BuildContext context, WidgetRef ref) async {
    final current = ref.read(customRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: current.firstDay,
        end: current.lastDay,
      ),
      helpText: 'Wybierz zakres',
    );
    if (picked == null) return false;
    ref.read(customRangeProvider.notifier).state = ReportRange(
      firstDay:
          DateTime.utc(picked.start.year, picked.start.month, picked.start.day),
      lastDay: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
    );
    ref.read(reportPeriodProvider.notifier).state = ReportPeriod.custom;
    return true;
  }

  void _shift(WidgetRef ref, ReportPeriod period, int direction) {
    if (period == ReportPeriod.custom) {
      final current = ref.read(customRangeProvider);
      ref.read(customRangeProvider.notifier).state =
          ReportRangeCalculator.shiftCustom(current, direction);
    } else {
      final anchor = ref.read(reportAnchorProvider);
      ref.read(reportAnchorProvider.notifier).state =
          ReportRangeCalculator.shift(period, anchor, direction);
    }
  }

  String _rangeLabel(ReportPeriod period, ReportRange range) {
    String d(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}';
    switch (period) {
      case ReportPeriod.day:
        return '${d(range.firstDay)}.${range.firstDay.year}';
      case ReportPeriod.week:
      case ReportPeriod.custom:
        return '${d(range.firstDay)} – ${d(range.lastDay)}';
      case ReportPeriod.month:
        const months = [
          'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
          'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
        ];
        return '${months[range.firstDay.month - 1]} ${range.firstDay.year}';
    }
  }
}
