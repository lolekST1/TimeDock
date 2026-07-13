import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/app_state/app_providers.dart';
import 'features/home/home_screen.dart';

class TimeDockApp extends ConsumerWidget {
  const TimeDockApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Theme follows the selected workspace's seed color.
    final workspaces = ref.watch(workspacesProvider).valueOrNull;
    final selectedId = ref.watch(selectedWorkspaceProvider);
    final seed = workspaces
            ?.where((w) => w.id == selectedId)
            .firstOrNull
            ?.colorSeed ??
        0xFF1565C0;

    return MaterialApp(
      title: 'TimeDock',
      debugShowCheckedModeBanner: false,
      theme: timeDockTheme(seed, Brightness.light),
      darkTheme: timeDockTheme(seed, Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
