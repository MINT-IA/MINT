import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';

void main() {
  test('authenticated sessions are redirected away from every auth entry route',
      () {
    final source = File('lib/app.dart').readAsStringSync();

    expect(
      source,
      contains('final authEntryRedirect = authSessionEntryRedirect('),
    );
    expect(source, contains('if (authEntryRedirect != null)'));
    expect(source, contains('return authEntryRedirect;'));
    for (final path in const [
      '/auth/login',
      '/auth/register',
      '/auth/verify',
    ]) {
      expect(source, contains("'$path'"), reason: path);
      expect(
        authSessionEntryRedirect(isLoggedIn: true, path: path),
        '/home',
        reason: path,
      );
    }
    for (final callbackPath in const [
      '/auth/forgot-password',
      '/auth/verify-email',
    ]) {
      expect(
        authSessionEntryRedirect(isLoggedIn: true, path: callbackPath),
        isNull,
        reason: callbackPath,
      );
    }
  });
}
