import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/core/upper_case_formatter.dart';

void main() {
  const formatter = UpperCaseTextFormatter();

  TextEditingValue format(String text) => formatter.formatEditUpdate(
        TextEditingValue.empty,
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      );

  test('upper-cases typed text and keeps the caret position', () {
    final result = format('ab1-12');
    expect(result.text, 'AB1-12');
    expect(result.selection.baseOffset, 'AB1-12'.length);
  });

  test('leaves already-upper-case text unchanged', () {
    expect(format('AB-2435').text, 'AB-2435');
  });
}
