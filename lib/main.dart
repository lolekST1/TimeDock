import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(seederProvider).seedIfEmpty();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const TimeDockApp(),
    ),
  );
}
