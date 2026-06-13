import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';

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
  });
}
