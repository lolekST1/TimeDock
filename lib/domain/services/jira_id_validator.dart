/// Validates the optional Jira issue key that lives on a [Task].
///
/// The field stays optional (§17 keeps Jira integration out of scope), so an
/// empty value is always allowed. When present it must look like `ABS-123`:
/// an upper-case letter, one or more upper-case letters/digits, a hyphen and
/// a run of digits. Pure and Flutter-free so the UI is a thin caller.
abstract final class JiraIdValidator {
  /// `PROJ-123`: upper-case prefix (letters/digits, starting with a letter)
  /// then a hyphen and a numeric suffix.
  static final RegExp _pattern = RegExp(r'^[A-Z][A-Z0-9]+-\d+$');

  /// True when [jiraId] is empty (allowed) or matches the Jira key format.
  /// A null or blank value counts as empty.
  static bool isValid(String? jiraId) {
    final value = jiraId?.trim() ?? '';
    if (value.isEmpty) return true;
    return _pattern.hasMatch(value);
  }

  /// Form-friendly validation: null when acceptable, otherwise a message.
  static String? validate(String? jiraId) =>
      isValid(jiraId) ? null : 'Nieprawidłowy format Jira ID (np. ABS-123)';
}
