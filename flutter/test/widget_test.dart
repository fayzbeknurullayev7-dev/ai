// Auth validatorlari uchun oddiy birlik testlari.
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_ai_agent/features/auth/presentation/widgets/auth_widgets.dart';

void main() {
  group('validateEmail', () {
    test('bo\'sh email — xato', () => expect(validateEmail(''), isNotNull));
    test('noto\'g\'ri format — xato',
        () => expect(validateEmail('test'), isNotNull));
    test('to\'g\'ri email — null',
        () => expect(validateEmail('a@b.com'), isNull));
  });

  group('validatePassword', () {
    test('bo\'sh parol — xato', () => expect(validatePassword(''), isNotNull));
    test('qisqa parol — xato',
        () => expect(validatePassword('123'), isNotNull));
    test('yetarli parol — null',
        () => expect(validatePassword('123456'), isNull));
  });
}
