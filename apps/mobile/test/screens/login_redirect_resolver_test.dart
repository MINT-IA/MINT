import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/screens/auth/auth_redirect.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    // La lecture canonique des réponses passe désormais par le secure store
    // (canonicalisation logement) — sans mock, la lecture échoue et le
    // dossier anonyme paraît vide.
    FlutterSecureStorage.setMockInitialValues({});
  });

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

  test(
      'post-auth destination completes dossier identity before answer surfaces',
      () {
    expect(
      resolvePostAuthDestination(
        currentUri: Uri.parse('/auth/register?redirect=%2Fanonymous%2Fchat'),
        hasDossierIdentity: false,
      ),
      '/onb',
    );
    expect(
      resolvePostAuthDestination(
        currentUri: Uri.parse(
          '/auth/login?redirect=%2Fcoach%2Fchat%3FconversationId%3Dabc',
        ),
        hasDossierIdentity: false,
      ),
      '/onb',
    );
    expect(
      resolvePostAuthDestination(
        currentUri: Uri.parse('/auth/login?redirect=%2Fsettings%2Flangue'),
        hasDossierIdentity: false,
      ),
      '/settings/langue',
    );
    expect(
      resolvePostAuthDestination(
        currentUri: Uri.parse('/auth/register'),
        hasDossierIdentity: true,
      ),
      '/home',
    );
  });

  test('post-auth fallback lands on Today when no explicit redirect exists',
      () {
    expect(
      resolvePostAuthDestination(
        currentUri: Uri.parse('/auth/register'),
        hasDossierIdentity: true,
      ),
      '/home',
    );
    expect(
      resolvePostAuthDestination(
        currentUri: Uri.parse('/auth/login'),
        hasDossierIdentity: false,
      ),
      '/onb',
    );
  });

  test('dossier identity accepts date of birth or birth year answers', () {
    expect(hasDossierIdentityAnswers({}), isFalse);
    expect(
      hasDossierIdentityAnswers({'q_date_of_birth': '1992-07-15'}),
      isTrue,
    );
    expect(hasDossierIdentityAnswers({'q_birth_year': 1992}), isTrue);
    expect(hasDossierIdentityAnswers({'q_birth_year': '1992'}), isTrue);
  });

  test('post-auth identity falls back to the anonymous dossier', () async {
    SharedPreferences.setMockInitialValues({
      'wizard_answers_v2': '{"q_date_of_birth":"1977-07-12"}',
    });

    expect(await hasPostAuthDossierIdentity(localDateOfBirth: null), isTrue);
  });
}
