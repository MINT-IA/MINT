import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _source(String relativePath) {
  final file = File(relativePath);
  return file.existsSync() ? file.readAsStringSync() : '';
}

void _expectStableIds(String source, Iterable<String> ids, String reason) {
  final missing = ids.where((id) => !source.contains(id)).toList();
  expect(
    missing,
    isEmpty,
    reason: '$reason Missing stable ids: ${missing.join(', ')}',
  );
}

void main() {
  final scanSource =
      _source('lib/screens/document_scan/document_scan_screen.dart');
  final reviewSource =
      _source('lib/screens/document_scan/extraction_review_screen.dart');
  final impactSource =
      _source('lib/screens/document_scan/document_impact_screen.dart');
  final dashboardSource =
      _source('lib/screens/coach/retirement_dashboard_screen.dart');
  final uiSource =
      '$scanSource\n$reviewSource\n$impactSource\n$dashboardSource';

  group('progressive represented-authorization rendering', () {
    test('retains the existing owner and immutable review controls', () {
      _expectStableIds(
        uiSource,
        const <String>[
          'lpp_acquisition_owner_manual_partner',
          'lpp_review_owner_badge',
          'lpp_review_confirm_cta',
        ],
        'PROV-02 controls are the entry seam for BND-02A.',
      );
    });

    test('renders notice, rights, declaration, and receipt recovery controls',
        () {
      _expectStableIds(
        uiSource,
        const <String>[
          'lpp_partner_external_gate_blocked',
          'lpp_partner_notice_gate',
          'lpp_partner_notice_version',
          'lpp_partner_notice_open',
          'lpp_partner_rights_link',
          'lpp_partner_authorization_declaration',
          'lpp_partner_authorization_continue',
          'lpp_partner_auth_required',
          'lpp_partner_receipt_pending',
          'lpp_partner_receipt_retry',
        ],
        'The partner journey must be progressive and recoverable before bytes.',
      );
    });

    test('renders caisse quarantine and the real retirement transition', () {
      _expectStableIds(
        uiSource,
        const <String>[
          'lpp_review_caisse_rate_quarantined',
          'lpp_impact_retirement_cta',
        ],
        'Review must expose the unused caisse fact and route to the real caller.',
      );
    });
  });

  group('dashboard accountability states', () {
    test('renders active, partial, retry, manual recovery, and rights', () {
      _expectStableIds(
        dashboardSource,
        const <String>[
          'retirement_partner_lpp_status_active',
          'retirement_partner_lpp_status_partial',
          'retirement_partner_lpp_retry_status',
          'retirement_partner_lpp_manual_recovery',
          'retirement_partner_lpp_rights_link',
        ],
        'The visible consumer must fail closed without hiding recovery.',
      );
    });

    test('does not ship a direct-confirmation facade', () {
      expect(uiSource, isNot(contains('direct_partner_confirmation')));
      expect(uiSource, isNot(contains('directPartnerConfirmation')));
    });
  });

  group('six-language notice contract', () {
    test('all ARBs carry the same activation-blocking key inventory', () {
      const requiredKeys = <String>[
        'lppPartnerNoticeTitle',
        'lppPartnerNoticeSummary',
        'lppPartnerNoticeVersion',
        'lppPartnerNoticeOpen',
        'lppPartnerRightsOpen',
        'lppPartnerNoLinkedAccount',
        'lppPartnerAuthorizationDeclaration',
        'lppPartnerAuthorizationContinue',
        'lppPartnerExternalGateBlocked',
        'lppPartnerAuthRequired',
        'lppPartnerReceiptFailed',
        'lppPartnerStatusActive',
        'lppPartnerStatusNeedsVerification',
        'lppPartnerStatusExpired',
        'lppPartnerStatusRevoked',
        'lppPartnerManualRecovery',
        'lppPartnerCaisseRateExcluded',
        'lppPartnerRetirementBenefitChanged',
      ];

      final missingByLocale = <String, List<String>>{};
      for (final locale in const <String>['fr', 'en', 'de', 'es', 'it', 'pt']) {
        final arb = _source('lib/l10n/app_$locale.arb');
        final missing =
            requiredKeys.where((key) => !arb.contains('"$key"')).toList();
        if (missing.isNotEmpty) missingByLocale[locale] = missing;
      }

      expect(
        missingByLocale,
        isEmpty,
        reason: 'No notice copy may ship with partial language semantics.',
      );
    });

    test('partner copy never upgrades the proxy declaration or invents proof',
        () {
      const partnerKeyPrefix = 'lppPartner';
      const forbiddenFragments = <String>[
        'direct_partner_confirmation',
        'directPartnerConfirmation',
        'directPartnerConsent',
        '/consents/grant-nominative',
        'opposable',
        'zero data retention',
        'Data Privacy Framework',
        'ZDR',
      ];

      for (final locale in const <String>['fr', 'en', 'de', 'es', 'it', 'pt']) {
        final arbSource = _source('lib/l10n/app_$locale.arb');
        final arb = arbSource.isEmpty
            ? const <String, dynamic>{}
            : jsonDecode(arbSource) as Map<String, dynamic>;
        final partnerCopy = arb.entries
            .where((entry) => entry.key.startsWith(partnerKeyPrefix))
            .map((entry) => entry.value)
            .whereType<String>()
            .join('\n');

        for (final fragment in forbiddenFragments) {
          expect(
            partnerCopy,
            isNot(contains(fragment)),
            reason:
                '$locale partner copy must not claim direct consent, opposability, or unverified transfer/retention guarantees.',
          );
        }
      }
    });
  });
}
