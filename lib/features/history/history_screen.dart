import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time_format.dart';
import '../../core/ui/td_card.dart';
import '../../core/ui/td_tokens.dart';
import '../../domain/repositories/session_repository.dart';
import '../../domain/services/day_timeline.dart';
import '../app_state/context_label.dart';
import 'history_providers.dart';
import 'session_editor_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late DateTime _day; // local-day key: DateTime.utc(y, m, d)

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime.utc(now.year, now.month, now.day);
  }

  void _shiftDay(int deltaDays) {
    setState(() => _day = _day.add(Duration(days: deltaDays)));
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day == DateTime.utc(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref
            .watch(dayTimelineProvider(DayKey(widget.workspaceId, _day)))
            .valueOrNull ??
        const [];
    final tracked = DayTimeline.trackedTotal(entries);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftDay(-1),
                ),
                TextButton(
                  onPressed: _isToday ? null : () => _shiftDay(_daysToToday()),
                  child: Text(
                    _isToday ? 'Dziś' : formatIsoDate(_day),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _isToday ? null : () => _shiftDay(1),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManual,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj sesję'),
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v > 200) {
            _shiftDay(-1); // swipe right → previous day
          } else if (v < -200 && !_isToday) {
            _shiftDay(1);
          }
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.timelapse_rounded,
                      size: 18, color: context.td.good),
                  const SizedBox(width: 8),
                  Text('Zmierzono',
                      style: TextStyle(
                          color: context.td.faint,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          letterSpacing: 0.3)),
                  const Spacer(),
                  Text(formatDurationShort(tracked),
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('Brak sesji tego dnia'))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      itemCount: entries.length,
                      itemBuilder: (context, i) =>
                          _EntryTile(entry: entries[i], workspaceId: widget.workspaceId),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  int _daysToToday() {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    return today.difference(_day).inDays;
  }

  Future<void> _addManual() async {
    // Default range: from the end of the last session today to now.
    final entries = ref
            .read(dayTimelineProvider(DayKey(widget.workspaceId, _day)))
            .valueOrNull ??
        const [];
    final lastBlock = entries.whereType<SessionBlock>().fold<DateTime?>(
        null,
        (latest, b) =>
            latest == null || b.endLocal.isAfter(latest) ? b.endLocal : latest);
    final now = DateTime.now();
    final defaultStart = lastBlock?.toUtc() ??
        DateTime(now.year, now.month, now.day, now.hour)
            .subtract(const Duration(hours: 1))
            .toUtc();

    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SessionEditorScreen(
        workspaceId: widget.workspaceId,
        initialStartUtc: defaultStart,
        initialEndUtc: DateTime.now().toUtc(),
      ),
    ));
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry, required this.workspaceId});

  final TimelineEntry entry;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final td = context.td;
    final timeRange =
        '${formatTimeOfDay(entry.startLocal)}–${formatTimeOfDay(entry.endLocal)}';

    if (entry is GapBlock) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(6, 3, 6, 3),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Center(
                child: Container(width: 2, height: 18, color: td.border),
              ),
            ),
            Icon(Icons.remove_circle_outline, size: 15, color: td.faint),
            const SizedBox(width: 7),
            Text(
              'Nierejestrowane · ${formatDurationShort(entry.duration)}',
              style: TextStyle(color: td.faint, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    final block = entry as SessionBlock;
    final session = block.session;
    final label = ref
        .watch(contextLabelProvider(SessionContext(
          workspaceId: session.workspaceId,
          projectId: session.projectId,
          subProjectId: session.subProjectId,
          taskId: session.taskId,
        )))
        .valueOrNull;
    final color = label == null ? td.faint : Color(label.color);
    final edited = session.wasEdited || session.isManuallyAdded;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: TdCard(
        padding: EdgeInsets.zero,
        clip: true,
        onTap: session.isRunning
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SessionEditorScreen(
                    workspaceId: workspaceId,
                    existing: session,
                  ),
                )),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(timeRange,
                              style: TextStyle(
                                  color: td.faint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ])),
                          const Spacer(),
                          if (session.isRunning) _Tag('w toku', td.good, td.goodBg),
                          if (edited) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.edit_note_rounded,
                                size: 16, color: td.faint),
                          ],
                          const SizedBox(width: 8),
                          Text(formatDurationShort(block.duration),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(label?.path ?? '…',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5)),
                      if (session.comment != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(session.comment!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  TextStyle(color: td.faint, fontSize: 12.5)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.fg, this.bg);

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}
