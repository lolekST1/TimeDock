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

    test('accepts both real project shapes (MM-2435 and EMS2-1203)', () {
      expect(JiraIdValidator.isValid('MM-2435'), isTrue);
      expect(JiraIdValidator.isValid('EMS2-12'), isTrue);
      expect(JiraIdValidator.isValid('EMS2-1203'), isTrue);
    });

    test('treats empty, null and whitespace as allowed (field is optional)', () {
      expect(JiraIdValidator.isValid(null), isTrue);
      expect(JiraIdValidator.isValid(''), isTrue);
      expect(JiraIdValidator.isValid('   '), isTrue);
    });

    test('trims surrounding whitespace before validating', () {
      expect(JiraIdValidator.isValid('  ABS-123  '), isTrue);
    });

    test('accepts lower-case entry (it is corrected to upper case)', () {
      expect(JiraIdValidator.isValid('abs-123'), isTrue);
      expect(JiraIdValidator.isValid('Abs-123'), isTrue);
      expect(JiraIdValidator.isValid('ems2-1203'), isTrue);
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

  group('JiraIdValidator.normalize', () {
    test('trims and upper-cases', () {
      expect(JiraIdValidator.normalize('abs-123'), 'ABS-123');
      expect(JiraIdValidator.normalize('  ems2-1203  '), 'EMS2-1203');
      expect(JiraIdValidator.normalize('MM-2435'), 'MM-2435');
    });

    test('null or blank yields an empty string', () {
      expect(JiraIdValidator.normalize(null), '');
      expect(JiraIdValidator.normalize('   '), '');
    });
  });

  group('JiraIdValidator.validate', () {
    test('returns null for allowed values', () {
      expect(JiraIdValidator.validate('ABS-123'), isNull);
      expect(JiraIdValidator.validate('abs-123'), isNull); // corrected to upper
      expect(JiraIdValidator.validate(''), isNull);
      expect(JiraIdValidator.validate(null), isNull);
    });

    test('returns an error message for malformed values', () {
      expect(JiraIdValidator.validate('ABS 123'), isNotNull);
      expect(JiraIdValidator.validate('nonsense'), isNotNull);
    });
  });
}
