import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Writes exports and rotating backups to the app's documents directory.
///
/// This is the thin platform-IO layer; all content generation (CSV/JSON) is
/// pure and tested elsewhere. Sharing the produced file via the OS share sheet
/// is a follow-up that needs a share plugin (see docs/export_backup.md).
class FileStore {
  const FileStore({this.maxBackups = 10});

  /// How many rotating backups to keep.
  final int maxBackups;

  Future<Directory> _exportsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/exports');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<Directory> _backupsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/backups');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}${two(n.second)}';
  }

  /// Writes [content] to `exports/<name>_<timestamp>.<ext>` and returns it.
  Future<File> writeExport(String name, String ext, String content) async {
    final dir = await _exportsDir();
    final file = File('${dir.path}/${name}_${_stamp()}.$ext');
    await file.writeAsString(content);
    return file;
  }

  /// Writes a backup and prunes old ones beyond [maxBackups].
  Future<File> writeBackup(String json) async {
    final dir = await _backupsDir();
    final file = File('${dir.path}/timedock_backup_${_stamp()}.json');
    await file.writeAsString(json);
    await _prune(dir);
    return file;
  }

  Future<List<File>> listBackups() async {
    final dir = await _backupsDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // newest first by timestamp
    return files;
  }

  Future<void> _prune(Directory dir) async {
    final backups = await listBackups();
    for (final file in backups.skip(maxBackups)) {
      if (file.existsSync()) file.deleteSync();
    }
  }
}
