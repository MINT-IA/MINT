import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/auth/auth_redirects.dart';

void main() {
  group('authInternalRedirect', () {
    test('keeps app-internal paths with query parameters', () {
      expect(
        authInternalRedirect('/coach/chat?topic=onboarding'),
        '/coach/chat?topic=onboarding',
      );
    });

    test('rejects absolute and protocol-relative redirects', () {
      expect(authInternalRedirect('https://example.com'), isNull);
      expect(authInternalRedirect('mint://coach/chat'), isNull);
      expect(authInternalRedirect('//example.com/path'), isNull);
    });

    test('rejects relative, empty, and malformed-looking redirects', () {
      expect(authInternalRedirect(null), isNull);
      expect(authInternalRedirect(''), isNull);
      expect(authInternalRedirect('coach/chat'), isNull);
      expect(authInternalRedirect(r'/\example.com'), isNull);
      expect(authInternalRedirect('/%2Fevil.com'), isNull);
      expect(authInternalRedirect('/%5Cexample.com'), isNull);
    });

    test('rejects auth entry points as post-auth destinations', () {
      expect(authInternalRedirect('/auth/login'), isNull);
      expect(authInternalRedirect('/auth/register?redirect=/home'), isNull);
    });

    test('falls back when no safe internal redirect is present', () {
      expect(
        authInternalRedirectOrFallback(
          'https://example.com',
          fallback: '/home',
        ),
        '/home',
      );
    });
  });
}
