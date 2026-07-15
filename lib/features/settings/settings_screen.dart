import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/colors.dart';
import '../../data/providers.dart';
import '../../domain/entities/workspace.dart';
import '../app_state/app_providers.dart';
import '../home/widgets/entity_dialogs.dart';
import 'archive_screen.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _thresholdOptions = [15, 30, 60, 120, 240, 360, 480];

  static String _minutesLabel(int minutes) => minutes < 60
      ? '$minutes min'
      : minutes % 60 == 0
          ? '${minutes ~/ 60} h'
          : '${minutes ~/ 60} h ${minutes % 60} min';

  /// The dropdown needs its value to be one of the items; snap a custom or
  /// migrated value to the nearest option.
  static int _closestOption(int minutes) =>
      _thresholdOptions.reduce((a, b) =>
          (a - minutes).abs() <= (b - minutes).abs() ? a : b);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const [];
    final selectedId = ref.watch(selectedWorkspaceProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        children: [
          _SectionTitle('Wygląd'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Jasny')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Ciemny')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => controller.setThemeMode(s.first),
            ),
          ),
          const Divider(),
          _SectionTitle('Zapomniany timer'),
          SwitchListTile(
            title: const Text('Przypominaj o długim timerze'),
            subtitle: const Text(
                'Ostrzeż, gdy timer działa dłużej niż próg, i proponuj przycięcie'),
            value: settings.forgottenTimerEnabled,
            onChanged: controller.setForgottenTimerEnabled,
          ),
          ListTile(
            enabled: settings.forgottenTimerEnabled,
            title: const Text('Próg przypomnienia'),
            subtitle: Text(_minutesLabel(settings.forgottenTimerThresholdMinutes)),
            trailing: DropdownButton<int>(
              value: _closestOption(settings.forgottenTimerThresholdMinutes),
              items: [
                for (final m in _thresholdOptions)
                  DropdownMenuItem(value: m, child: Text(_minutesLabel(m))),
              ],
              onChanged: settings.forgottenTimerEnabled
                  ? (m) {
                      if (m != null) {
                        controller.setForgottenTimerThresholdMinutes(m);
                      }
                    }
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.alarm_on_outlined),
            title: const Text('Powiadomienia w tle'),
            subtitle: const Text(
                'Zezwól na dokładne alarmy, aby przypomnienie działało przy '
                'wygaszonym ekranie (wymagane na Oppo/Xiaomi/Samsung)'),
            isThreeLine: true,
            onTap: () => _fixReminderPermissions(context, ref),
          ),
          const Divider(),
          _SectionTitle('Domyślne eksportu'),
          SwitchListTile(
            title: const Text('Godziny dziesiętne'),
            subtitle: const Text('1.25 zamiast 1:15'),
            value: settings.exportDecimalHours,
            onChanged: controller.setExportDecimalHours,
          ),
          SwitchListTile(
            title: const Text('Zaokrąglaj do 15 minut w górę'),
            subtitle: const Text('Tylko w eksporcie; baza trzyma czas rzeczywisty'),
            value: settings.exportRoundTo15,
            onChanged: controller.setExportRoundTo15,
          ),
          const Divider(),
          _SectionTitle('Przestrzenie (workspace)'),
          for (final w in workspaces)
            ListTile(
              leading: CircleAvatar(
                  radius: 10, backgroundColor: Color(w.colorSeed)),
              title: Text(w.name),
              subtitle: w.weeklyGoalMinutes != null
                  ? Text('Cel: ${w.weeklyGoalMinutes! ~/ 60} h / tydzień')
                  : null,
              trailing: PopupMenuButton<String>(
                onSelected: (action) =>
                    _onWorkspaceAction(context, ref, w, action, workspaces.length),
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'rename', child: Text('Zmień nazwę')),
                  const PopupMenuItem(value: 'color', child: Text('Zmień kolor')),
                  const PopupMenuItem(
                      value: 'goal', child: Text('Cel tygodniowy')),
                  if (workspaces.length > 1)
                    const PopupMenuItem(
                        value: 'archive', child: Text('Archiwizuj')),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Dodaj przestrzeń'),
            onTap: () => _addWorkspace(context, ref, workspaces.length),
          ),
          const Divider(),
          _SectionTitle('Archiwum'),
          ListTile(
            leading: const Icon(Icons.unarchive_outlined),
            title: const Text('Zarchiwizowane projekty'),
            subtitle: const Text('Przywróć ukryte w archiwum projekty'),
            enabled: selectedId != null,
            onTap: selectedId == null
                ? null
                : () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ArchiveScreen(workspaceId: selectedId),
                    )),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _fixReminderPermissions(
      BuildContext context, WidgetRef ref) async {
    final ok = await ref.read(reminderSchedulerProvider).ensureExactAlarms();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok
            ? 'Dokładne alarmy włączone — przypomnienie zadziała w tle.'
            : 'Włącz „Alarmy i przypomnienia" oraz autostart aplikacji '
                'w ustawieniach systemu, aby przypomnienie działało w tle.'),
      ));
  }

  Future<void> _addWorkspace(
      BuildContext context, WidgetRef ref, int existingCount) async {
    final name = await promptForName(context, title: 'Nowa przestrzeń');
    if (name == null) return;
    final now = DateTime.now().toUtc();
    await ref.read(workspaceRepositoryProvider).upsert(Workspace(
          id: const Uuid().v4(),
          name: name,
          colorSeed: kEntityColors[existingCount % kEntityColors.length],
          sortOrder: existingCount,
          createdAt: now,
          updatedAt: now,
        ));
  }

  Future<void> _onWorkspaceAction(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
    String action,
    int activeCount,
  ) async {
    final repo = ref.read(workspaceRepositoryProvider);
    final now = DateTime.now().toUtc();
    switch (action) {
      case 'rename':
        final name = await promptForName(context,
            title: 'Nazwa przestrzeni', initial: workspace.name);
        if (name != null) {
          await repo.upsert(workspace.copyWith(name: name, updatedAt: now));
        }
      case 'color':
        final color = await pickEntityColor(context, workspace.colorSeed);
        if (color != null) {
          await repo.upsert(workspace.copyWith(colorSeed: color, updatedAt: now));
        }
      case 'goal':
        final hours = await _pickGoalHours(
            context, (workspace.weeklyGoalMinutes ?? 0) ~/ 60);
        if (hours != null) {
          await repo.upsert(workspace.copyWith(
            weeklyGoalMinutes: hours == 0 ? null : hours * 60,
            updatedAt: now,
          ));
        }
      case 'archive':
        // Never archive the last active workspace; move selection away first.
        if (activeCount <= 1) return;
        final selected = ref.read(selectedWorkspaceProvider);
        if (selected == workspace.id) {
          final other = (ref.read(workspacesProvider).valueOrNull ?? const [])
              .where((w) => w.id != workspace.id)
              .firstOrNull;
          if (other != null) {
            await ref
                .read(selectedWorkspaceProvider.notifier)
                .select(other.id);
          }
        }
        await repo.upsert(workspace.copyWith(isArchived: true, updatedAt: now));
    }
  }

  Future<int?> _pickGoalHours(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Cel tygodniowy'),
        children: [
          for (final h in const [0, 5, 10, 20, 30, 40])
            RadioListTile<int>(
              value: h,
              groupValue: current,
              title: Text(h == 0 ? 'Brak celu' : '$h h / tydzień'),
              onChanged: (v) => Navigator.of(context).pop(v),
            ),
        ],
      ),
    );
  }

}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
