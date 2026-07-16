import 'package:flutter_test/flutter_test.dart';
import 'package:timedock/domain/services/jira_id_validator.dart';

void main() {
  group('JiraIdValidator.isValid', () {
    test('accepts well-formed keys', () {
      expect(JiraIdValidator.isValid('ABS-123'), isTrue);
      expect(JiraIdValidator.isValid('DAN-1234'), isTrue);
      expect(JiraIdValidator.isValid('BUG-1'), isTrue);
      expect(JiraIdValidator.isValid('A1B2-9'), isTrue); // digits in prefix
    });

    test('treats empty, null and whitespace as allowed (field is optional)', () {
      expect(JiraIdValidator.isValid(null), isTrue);
      expect(JiraIdValidator.isValid(''), isTrue);
      expect(JiraIdValidator.isValid('   '), isTrue);
    });

    test('trims surrounding whitespace before validating', () {
      expect(JiraIdValidator.isValid('  ABS-123  '), isTrue);
    });

    test('rejects lower-case letters in the prefix', () {
      expect(JiraIdValidator.isValid('abs-123'), isFalse);
      expect(JiraIdValidator.isValid('Abs-123'), isFalse);
    });

    test('rejects a missing hyphen', () {
      expect(JiraIdValidator.isValid('ABS123'), isFalse);
    });

    test('rejects a missing numeric suffix', () {
      expect(JiraIdValidator.isValid('ABS-'), isFalse);
      expect(JiraIdValidator.isValid('ABS-ABC'), isFalse);
    });

    test('rejects a bare prefix without the key part', () {
      expect(JiraIdValidator.isValid('A-1'), isFalse); // prefix needs 2+ chars
    });

    test('rejects a prefix starting with a digit', () {
      expect(JiraIdValidator.isValid('1BS-123'), isFalse);
    });

    test('rejects extra tokens or separators', () {
      expect(JiraIdValidator.isValid('ABS-123-4'), isFalse);
      expect(JiraIdValidator.isValid('ABS 123'), isFalse);
    });
  });

  group('JiraIdValidator.validate', () {
    test('returns null for allowed values', () {
      expect(JiraIdValidator.validate('ABS-123'), isNull);
      expect(JiraIdValidator.validate(''), isNull);
      expect(JiraIdValidator.validate(null), isNull);
    });

    test('returns an error message for malformed values', () {
      expect(JiraIdValidator.validate('abs-123'), isNotNull);
    });
  });
}
