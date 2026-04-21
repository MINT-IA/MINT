import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

/// Wave 7 edge-case audit C1 — regression guard for the canton
/// normalisation helper added in [resolveCanton]. Every simulator
/// previously fell back on 'ZH' silently when `profile.canton` was
/// null, empty, whitespace, lowercase, or an invalid code; that
/// meant a VS/GE user was silently shown ZH tax math. This test
/// pins the helper's behaviour so any regression is caught before
/// those simulators ship.
void main() {
  group('resolveCanton', () {
    test('null input → fallback ZH with isResolved=false', () {
      final r = resolveCanton(null);
      expect(r.code, 'ZH');
      expect(r.isResolved, isFalse);
      expect(r.isFallback, isTrue);
    });

    test('empty string → fallback ZH with isResolved=false', () {
      final r = resolveCanton('');
      expect(r.code, 'ZH');
      expect(r.isResolved, isFalse);
    });

    test('whitespace-only → fallback ZH', () {
      final r = resolveCanton('   ');
      expect(r.code, 'ZH');
      expect(r.isResolved, isFalse);
    });

    test('lowercase valid code → normalised to uppercase, resolved', () {
      final r = resolveCanton('vs');
      expect(r.code, 'VS');
      expect(r.isResolved, isTrue);
      expect(r.rawInput, 'vs');
    });

    test('leading/trailing whitespace stripped', () {
      final r = resolveCanton('  GE  ');
      expect(r.code, 'GE');
      expect(r.isResolved, isTrue);
    });

    test('unknown code → fallback ZH with isResolved=false', () {
      final r = resolveCanton('XX');
      expect(r.code, 'ZH');
      expect(r.isResolved, isFalse);
      expect(r.rawInput, 'XX');
    });

    test('full country name is rejected (requires ISO-2 code)', () {
      final r = resolveCanton('Geneva');
      expect(r.code, 'ZH');
      expect(r.isResolved, isFalse);
    });

    test('all 26 canton codes resolve cleanly', () {
      for (final code in sortedCantonCodes) {
        final r = resolveCanton(code);
        expect(r.code, code, reason: '$code should resolve to itself');
        expect(r.isResolved, isTrue,
            reason: '$code must be marked as resolved');
      }
    });
  });
}
