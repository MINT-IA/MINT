import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/auth/auth_redirect.dart';

void main() {
  test('resolvePostAuthRedirect prefers safe redirect query param', () {
    expect(
      resolvePostAuthRedirect(Uri.parse(
        '/auth/login?redirect=%2Fcoach%2Fchat%3FconversationId%3Dabc',
      )),
      '/coach/chat?conversationId=abc',
    );
    expect(
      resolvePostAuthRedirect(Uri.parse('/auth/login?redirect=https://x')),
      isNull,
    );
    expect(
      resolvePostAuthRedirect(Uri.parse('/auth/login?redirect=%2F%2Fx')),
      isNull,
    );
    expect(
      resolvePostAuthRedirect(Uri.parse('/auth/login?redirect=%2Fbad%5Cpath')),
      isNull,
    );
    expect(
      resolvePostAuthRedirect(Uri.parse('/auth/login?redirect=%25')),
      isNull,
    );
    expect(
      resolvePostAuthRedirect(Uri.parse('/auth/login?redirect=%2Fbad%0Apath')),
      isNull,
    );
  });

  test('authRouteWithRedirect preserves only safe internal redirects', () {
    expect(
      authRouteWithRedirect(
        '/auth/verify-email',
        Uri.parse('/auth/register?redirect=%2Fanonymous%2Fchat'),
      ),
      '/auth/verify-email?redirect=%2Fanonymous%2Fchat',
    );
    expect(
      authRouteWithRedirect(
        '/auth/verify-email',
        Uri.parse('/auth/register?redirect=https://x'),
      ),
      '/auth/verify-email',
    );
  });
}
