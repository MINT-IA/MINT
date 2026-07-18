import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _locales = <String>['fr', 'en', 'de', 'es', 'it', 'pt'];
const _keys = <String>{
  'lpp_capital_notice_deadline_question',
  'lpp_capital_notice_deadline_field',
  'lpp_capital_notice_deadline_hint',
  'lpp_capital_notice_partial_state',
  'lpp_capital_notice_record_retry_state',
  'lpp_capital_notice_record_retry_cta',
  'lpp_capital_notice_continue_without_deadline_cta',
};

Map<String, dynamic> _arb(String locale) => jsonDecode(
      File('lib/l10n/app_$locale.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

void main() {
  test('capital notice acquisition copy is complete across all six ARBs', () {
    for (final locale in _locales) {
      final arb = _arb(locale);
      for (final key in _keys) {
        expect(arb[key], isA<String>(), reason: '$locale:$key');
        expect((arb[key] as String).trim(), isNotEmpty, reason: '$locale:$key');
      }
    }
  });

  test('French copy states the bounded educational declaration contract', () {
    final arb = _arb('fr');
    final question = arb['lpp_capital_notice_deadline_question'] as String;
    final hint = arb['lpp_capital_notice_deadline_hint'] as String;
    final partial = arb['lpp_capital_notice_partial_state'] as String;
    final all = '$question $hint $partial'.toLowerCase();

    expect(all, contains('non vérifiée'));
    expect(all, contains('date civile complète'));
    expect(all, contains('délai relatif'));
    expect(all, contains('institution'));
    expect(all, contains('droit perdu'));
    expect(all, contains('option acceptée'));
    expect(all, contains('éducative'));
    expect(all, contains('pas un conseil'));
  });
}
