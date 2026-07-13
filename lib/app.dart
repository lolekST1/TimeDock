import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';

const _defaultSeed = 0xFF1565C0;

class TimeDockApp extends ConsumerWidget {
  const TimeDockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'TimeDock',
      theme: timeDockTheme(_defaultSeed, Brightness.light),
      darkTheme: timeDockTheme(_defaultSeed, Brightness.dark),
      home: const _PlaceholderHome(),
    );
  }
}

/// Replaced by the real home screen in stage 2.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('TimeDock')),
    );
  }
}
