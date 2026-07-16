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
/// Note: iPad would additionally need `sharePositionOrigin`; not set here as
/// Android is the only shipping platform.
class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  /// Generic MIME type used on purpose. The written file already carries the
  /// correct single extension (`.json`/`.csv`); with a specific MIME
  /// (`application/json`, `text/csv`) some Android receivers re-append the
  /// extension they map from that type, producing `foo.json.json`. A generic
  /// type has no such mapping, so the receiver keeps the real filename. Target
  /// apps still open the file by its extension.
  static const _genericMimeType = '*/*';

  @override
  Future<void> shareFile(String path, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path, mimeType: _genericMimeType)],
      subject: subject,
    ));
  }
}
