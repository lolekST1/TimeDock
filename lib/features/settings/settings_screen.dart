import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/providers.dart';
import '../../domain/entities/workspace.dart';
import '../app_state/app_providers.dart';
import '../home/widgets/entity_dialogs.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static const _workspaceColors = [
    0xFF1565C0, 0xFF00695C, 0xFF6A1B9A, 0xFFAD1457,
    0xFF4E342E, 0xFF283593, 0xFF00838F, 0xFFEF6C00,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final workspaces = ref.watch(workspacesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Ustawienia')),
      body: ListView(
        children: [
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
            subtitle: Text('${settings.forgottenTimerThresholdHours} h'),
            trailing: DropdownButton<int>(
              value: settings.forgottenTimerThresholdHours,
              items: [
                for (final h in const [1, 2, 3, 4, 6, 8, 10, 12])
                  DropdownMenuItem(value: h, child: Text('$h h')),
              ],
              onChanged: settings.forgottenTimerEnabled
                  ? (h) {
                      if (h != null) {
                        controller.setForgottenTimerThresholdHours(h);
                      }
                    }
                  : null,
            ),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _addWorkspace(
      BuildContext context, WidgetRef ref, int existingCount) async {
    final name = await promptForName(context, title: 'Nowa przestrzeń');
    if (name == null) return;
    final now = DateTime.now().toUtc();
    await ref.read(workspaceRepositoryProvider).upsert(Workspace(
          id: const Uuid().v4(),
          name: name,
          colorSeed: _workspaceColors[existingCount % _workspaceColors.length],
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
        final color = await _pickColor(context, workspace.colorSeed);
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

  Future<int?> _pickColor(BuildContext context, int current) {
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kolor przestrzeni'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final c in _workspaceColors)
              InkWell(
                onTap: () => Navigator.of(context).pop(c),
                child: CircleAvatar(
                  backgroundColor: Color(c),
                  child: c == current
                      ? const Icon(Icons.check, color: Colors.white)
                      : null,
                ),
              ),
          ],
        ),
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
