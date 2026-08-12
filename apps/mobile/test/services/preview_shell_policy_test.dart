import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';

void main() {
  test('the policy derives every semantic property from the single '
      'compile-time define', () {
    const off = PreviewShellPolicy.forTest(isPreviewShell: false);
    expect(off.showCoachTab, isTrue);
    expect(off.showExplorerTab, isTrue);
    expect(off.showLegacyTodayCards, isTrue);
    expect(off.showLegacyBudgetHero, isTrue);
    expect(off.showLegacyCoachWhisper, isTrue);
    expect(off.showLegacySituationMaps, isTrue);
    expect(off.showLegacySectionSelector, isTrue);
    expect(off.blocksRoute('/coach/chat'), isFalse,
        reason: 'hors préversion, comportement STRICTEMENT inchangé');

    const on = PreviewShellPolicy.forTest(isPreviewShell: true);
    expect(on.showCoachTab, isFalse);
    expect(on.showExplorerTab, isFalse);
    expect(on.showLegacyTodayCards, isFalse);
    expect(on.showLegacyBudgetHero, isFalse);
    expect(on.showLegacyCoachWhisper, isFalse);
    expect(on.showLegacySituationMaps, isFalse);
    expect(on.showLegacySectionSelector, isFalse);
    expect(on.blocksRoute('/coach/chat'), isTrue,
        reason: 'enforcement au point de destination — les alias '
            'owner:system héritent du blocage via cette cible gardée');
    expect(on.blocksRoute('/mint-next/vertical-3a'), isFalse);
    expect(on.forbiddenRouteRedirect, '/home');
  });

  test('no screen reads the preview define outside the policy', () {
    final offenders = <String>[];
    for (final f in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (f.path.endsWith('services/preview_shell_policy.dart')) continue;
      if (f.readAsStringSync().contains('MINT_NEXT_PREVIEW')) {
        offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty,
        reason: 'unique point de vérité — doublé par le guard commit-gate '
            'preview-shell (fixtures pass/fail)');
  });
}
