import 'package:flutter/services.dart';

/// Forces a text field's content to upper case as the user types. Jira ids are
/// always upper case, so lower-case entry is corrected in place rather than
/// flagged as invalid. The canonical form is enforced again on save via
/// `JiraIdValidator.normalize`.
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
