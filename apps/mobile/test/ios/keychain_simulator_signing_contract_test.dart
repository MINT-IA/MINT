import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug simulator Runner embeds its Keychain entitlements', () {
    final debugConfig = File('ios/Flutter/Debug.xcconfig').readAsStringSync();
    expect(
      debugConfig,
      matches(
        RegExp(
          r'^ENTITLEMENTS_ALLOWED\[sdk=iphonesimulator\*\]\s*=\s*YES\s*$',
          multiLine: true,
        ),
      ),
    );
    expect(
      debugConfig,
      matches(
        RegExp(
          r'^ENTITLEMENTS_DESTINATION\[sdk=iphonesimulator\*\]\s*=\s*__entitlements\s*$',
          multiLine: true,
        ),
      ),
    );
    expect(
      debugConfig,
      matches(
        RegExp(
          r'^CODE_SIGN_ENTITLEMENTS\[sdk=iphonesimulator\*\]\s*=\s*Runner/Runner-Simulator\.entitlements\s*$',
          multiLine: true,
        ),
      ),
    );

    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final debugRunner = RegExp(
      r'baseConfigurationReference = [^;]+ /\* Debug\.xcconfig \*/;'
      r'(?<settings>[\s\S]*?)name = Debug;',
    ).firstMatch(project);
    expect(debugRunner, isNotNull);
    expect(
      debugRunner!.namedGroup('settings'),
      contains('"CODE_SIGNING_ALLOWED[sdk=iphonesimulator*]" = YES;'),
    );
    expect(
      debugRunner.namedGroup('settings'),
      contains(
        '"CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]" = '
        '"Runner/Runner-Simulator.entitlements";',
      ),
    );
    final runnerTarget = RegExp(
      r'/\* Runner \*/ = \{\s+isa = PBXNativeTarget;'
      r'[\s\S]*?buildPhases = \('
      r'(?<phases>[\s\S]*?)\);',
    ).firstMatch(project);
    expect(runnerTarget, isNotNull);
    final phases = runnerTarget!.namedGroup('phases')!;
    expect(
      phases.indexOf('Thin Binary'),
      lessThan(phases.indexOf('Strip xattrs before codesign')),
      reason: 'Flutter embedding must finish before app xattrs are stripped',
    );
    expect(
      phases.indexOf('[CP] Copy Pods Resources'),
      lessThan(phases.indexOf('Strip xattrs before codesign')),
      reason: 'final copied resources must be stripped before app codesign',
    );

    const simulatorEntitlementsPath =
        'ios/Runner/Runner-Simulator.entitlements';
    final simulatorEntitlements =
        File(simulatorEntitlementsPath).readAsStringSync();
    expect(
      simulatorEntitlements,
      contains('<string>\$(AppIdentifierPrefix)ch.mint.app</string>'),
    );
    final parsed = Process.runSync(
      'plutil',
      ['-convert', 'json', '-o', '-', simulatorEntitlementsPath],
    );
    expect(parsed.exitCode, 0, reason: parsed.stderr as String?);
    final keys = (jsonDecode(parsed.stdout as String) as Map<String, dynamic>)
        .keys
        .toList();
    expect(keys, ['keychain-access-groups']);
  });
}
