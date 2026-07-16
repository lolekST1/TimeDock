/// Validates and canonicalises the optional Jira issue key that lives on a
/// [Task].
///
/// The field stays optional (§17 keeps Jira integration out of scope), so an
/// empty value is always allowed. When present it must look like `ABS-123` or
/// `EMS2-1203`: an upper-case letter, one or more upper-case letters/digits, a
/// hyphen and a run of digits. Keys are always stored upper case, so lower-case
/// entry (`abs-123`) is corrected rather than rejected. Pure and Flutter-free
/// so the UI is a thin caller.
abstract final class JiraIdValidator {
  /// `PROJ-123`: upper-case prefix (letters/digits, starting with a letter)
  /// then a hyphen and a numeric suffix.
  static final RegExp _pattern = RegExp(r'^[A-Z][A-Z0-9]+-\d+$');

  /// Canonical form: trimmed and upper-cased. This is what gets stored, so a
  /// key typed in lower case ends up upper case. Null or blank yields `''`.
  static String normalize(String? jiraId) => (jiraId ?? '').trim().toUpperCase();

  /// True when [jiraId] is empty (allowed) or its normalized form matches the
  /// Jira key format. Lower-case input is accepted (it normalizes to a match).
  static bool isValid(String? jiraId) {
    final value = normalize(jiraId);
    if (value.isEmpty) return true;
    return _pattern.hasMatch(value);
  }

  /// Form-friendly validation: null when acceptable, otherwise a message.
  static String? validate(String? jiraId) =>
      isValid(jiraId) ? null : 'Nieprawidłowy format Jira ID (np. ABS-123)';
}
