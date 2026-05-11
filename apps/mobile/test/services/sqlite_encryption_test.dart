// ─────────────────────────────────────────────────────────────────────────────
// T002 — SQLite encryption at rest (Phase 97 W7 iter#10).
//
// GDPR Art. 32 « security of processing » + Swiss DSG/LPD Art. 8.
//
// MINT mobile stores user biography (salary, pension data, financial
// snapshots) in a local SQLite database. The on-disk file MUST be
// encrypted at rest. If the device is stolen / jailbroken / the
// sandbox is dumped via idevicebackup2 / a malicious app reads
// shared Files-app folders, the DB bytes MUST NOT reveal user PII.
//
// This test pins the encryption contract :
//
//   1. The repository implementation imports `sqflite_sqlcipher`,
//      NOT plain `sqflite` (plain sqflite produces an unencrypted
//      DB file even with a `password:` parameter — the parameter is
//      silently ignored because the binary has no SQLCipher binding).
//
//   2. The repository calls `openDatabase` with a `password:` parameter
//      sourced from `flutter_secure_storage` (Keychain on iOS,
//      KeyStore on Android — hardware-backed when available).
//
//   3. The encryption key is 32 bytes (256-bit) of CSPRNG output
//      (Random.secure()) — verifiable from the generator code.
//
//   4. The key alias matches the documented contract
//      (`mint_biography_key`) so a future refactor that renames the
//      alias and silently locks users out is caught by this test.
//
// Why static-file assertions rather than runtime PRAGMA cipher_version :
//   `flutter test` runs in a Dart VM sandbox with no native SQLite
//   bindings. `sqflite_sqlcipher`'s `openDatabase` requires the
//   iOS/Android platform channel — not reachable from `flutter test`.
//   Maestro on-sim is the runtime gate ; this test is the SOURCE-CODE
//   contract gate that pins the package import + API shape so any
//   PR that downgrades to plain `sqflite` (or removes the `password:`
//   parameter) fails CI immediately.
//
// See : T002 row in `97-BUGS-REGISTRY.md` ; Phase 97 W7 iter#10 SUMMARY.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('T002 — SQLite at-rest encryption contract', () {
    late File repoFile;
    late String src;

    setUpAll(() {
      repoFile = File('lib/services/biography/biography_repository.dart');
      expect(
        repoFile.existsSync(),
        isTrue,
        reason:
            'biography_repository.dart must exist — it is the canonical SQLite '
            'persistence path on mobile.',
      );
      src = repoFile.readAsStringSync();
    });

    test(
      'repository imports sqflite_sqlcipher, never plain sqflite',
      () {
        expect(
          src.contains("import 'package:sqflite_sqlcipher/sqflite.dart'"),
          isTrue,
          reason:
              'T002 CONTRACT : BiographyRepository must import '
              '`sqflite_sqlcipher` (SQLCipher AES-256-CBC binding). '
              'Plain `package:sqflite/sqflite.dart` produces an '
              'unencrypted DB file and silently ignores any `password:` '
              'parameter.',
        );

        // Reject any plain-sqflite import (catches a future PR that
        // adds a second persistence path on plain sqflite).
        final hasPlainSqfliteImport = RegExp(
          r"^\s*import\s+'package:sqflite/sqflite\.dart'",
          multiLine: true,
        ).hasMatch(src);
        expect(
          hasPlainSqfliteImport,
          isFalse,
          reason:
              'T002 CONTRACT : no plain `sqflite` import allowed in the '
              'biography repository. Any future SQLite persistence path '
              'must also be wired through sqflite_sqlcipher.',
        );
      },
    );

    test(
      'openDatabase is called with a password: parameter (SQLCipher key)',
      () {
        // The encrypted DB is opened via :
        //   await sqflite.openDatabase(dbPath, password: key, ...)
        // We assert the literal `password: ` is present in the file —
        // a downgrade that removes this parameter falls back to an
        // unencrypted DB silently.
        expect(
          src.contains('password: key'),
          isTrue,
          reason:
              'T002 CONTRACT : `openDatabase(...)` must be called with '
              '`password: key` (the 32-byte SQLCipher key). Removing '
              'this parameter produces an unencrypted DB without any '
              'compile-time error from sqflite_sqlcipher.',
        );
      },
    );

    test(
      'encryption key is sourced from flutter_secure_storage (Keychain)',
      () {
        expect(
          src.contains(
            "import 'package:flutter_secure_storage/flutter_secure_storage.dart'",
          ),
          isTrue,
          reason:
              'T002 CONTRACT : the SQLCipher key MUST be persisted in '
              '`flutter_secure_storage` (iOS Keychain / Android '
              'KeyStore, hardware-backed when available). A key stored '
              'in SharedPreferences or a flat file would defeat the '
              'at-rest encryption.',
        );
        expect(
          src.contains('FlutterSecureStorage'),
          isTrue,
          reason: 'FlutterSecureStorage type must be referenced.',
        );
      },
    );

    test(
      'encryption key is 32 bytes of CSPRNG output (Random.secure)',
      () {
        // The generator returns a 64-char hex string (= 32 bytes = 256
        // bits) using `Random.secure()`. A downgrade to `Random()`
        // (PRNG, not CSPRNG) would produce a predictable key and is
        // caught here.
        expect(
          src.contains('Random.secure()'),
          isTrue,
          reason:
              'T002 CONTRACT : the SQLCipher key generator MUST use '
              '`Random.secure()` (CSPRNG-backed). `Random()` is a '
              'deterministic PRNG and would make the key recoverable.',
        );

        // 32-byte length proof : the generator uses
        // `List.generate(32, ...)` to produce 32 random bytes.
        expect(
          src.contains('List.generate(32,'),
          isTrue,
          reason:
              'T002 CONTRACT : the SQLCipher key MUST be 32 bytes '
              '(AES-256). A shorter key (16 / 24 bytes) silently '
              'downgrades the cipher strength.',
        );
      },
    );

    test(
      'key alias matches the documented contract (mint_biography_key)',
      () {
        // The alias is the lookup key inside flutter_secure_storage.
        // A silent rename would orphan existing user data (re-key on
        // upgrade — data loss). This assertion pins the alias.
        expect(
          src.contains("_keyAlias = 'mint_biography_key'"),
          isTrue,
          reason:
              'T002 CONTRACT : the SecureStorage key alias is '
              '`mint_biography_key`. Renaming this alias without a '
              'migration would orphan existing users\' encrypted data.',
        );
      },
    );

    test(
      'DB filename matches the documented contract (mint_biography.db)',
      () {
        expect(
          src.contains("_dbName = 'mint_biography.db'"),
          isTrue,
          reason:
              'T002 CONTRACT : the encrypted DB file lives at '
              '`<ApplicationDocumentsDirectory>/mint_biography.db`. A '
              'silent rename would leave the old plaintext-era file '
              'behind on disk.',
        );
      },
    );
  });
}
