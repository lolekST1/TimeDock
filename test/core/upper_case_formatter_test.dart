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
    final result = format('ems2-12');
    expect(result.text, 'EMS2-12');
    expect(result.selection.baseOffset, 'EMS2-12'.length);
  });

  test('leaves already-upper-case text unchanged', () {
    expect(format('MM-2435').text, 'MM-2435');
  });
}
