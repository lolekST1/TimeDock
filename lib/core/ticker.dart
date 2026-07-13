import 'dart:async';

import 'package:flutter/widgets.dart';

import 'time_format.dart';

/// Renders the elapsed time since [startUtc], updating once per second.
///
/// The clock is derived on every tick from `DateTime.now()` minus [startUtc],
/// never accumulated — so it stays correct if a tick is late, the app was
/// backgrounded, or the process was killed and relaunched.
class TimerCounter extends StatefulWidget {
  const TimerCounter({
    super.key,
    required this.startUtc,
    this.style,
  });

  final DateTime startUtc;
  final TextStyle? style;

  @override
  State<TimerCounter> createState() => _TimerCounterState();
}

class _TimerCounterState extends State<TimerCounter> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().toUtc().difference(widget.startUtc);
    final clamped = elapsed.isNegative ? Duration.zero : elapsed;
    return Text(formatCounter(clamped), style: widget.style);
  }
}
