import 'package:share_plus/share_plus.dart';

/// Hands a produced file (export/backup) to the OS share sheet so it can leave
/// the device — the app writes exports to its private documents directory,
/// which a file manager can't reach, so sharing is how the worklog JSON
/// actually gets to the downstream timesheet app, Drive, e-mail, etc.
///
/// Abstract so tests use a no-op and the platform integration stays isolated
/// (mirrors [ReminderScheduler]).
abstract interface class FileSharer {
  /// Opens the share sheet for the file at [path]. [subject] seeds the title
  /// for targets that use one (e.g. e-mail). Best-effort: a user who dismisses
  /// the sheet is not an error.
  Future<void> shareFile(String path, {String? subject});
}

/// No-op sharer for tests and platforms without a share sheet.
class NoopFileSharer implements FileSharer {
  const NoopFileSharer();

  @override
  Future<void> shareFile(String path, {String? subject}) async {}
}

/// Shares via `share_plus`. Works on Android (first target) and cross-platform.
/// The MIME type is left to share_plus to infer from the file extension
/// (`application/json`, `text/csv`) so receivers advertise the right type and
/// "open with" filtering works. Known cosmetic quirk: Notion re-appends the
/// extension it maps from that type, yielding `foo.json.json`; other targets
/// keep the correct single-extension name, so this is left as-is.
/// Note: iPad would additionally need `sharePositionOrigin`; not set here as
/// Android is the only shipping platform.
class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<void> shareFile(String path, {String? subject}) async {
    await SharePlus.instance
        .share(ShareParams(files: [XFile(path)], subject: subject));
  }
}
