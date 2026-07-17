import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _visualReadyMarkerName = 'mint-g1-front01-visual-ready-v1.marker';
const _visualReadyMarkerPayload = 'MINT_G1_FRONT01_VISUAL_READY_V1\n';

Finder _countryOverlayOption(String code) => find.byWidgetPredicate(
      (widget) =>
          widget is Text && (widget.data?.trim().endsWith('($code)') ?? false),
      description: 'Visible country option ending in ($code)',
    );

Finder _cantonOverlayOption(String code) => find.byWidgetPredicate(
      (widget) => widget is Text && widget.data?.trim() == code,
      description: 'Visible canton option $code',
    );

void main() {
  patrolTest(
    'collects the canonical frontier jurisdictions without inventing a result',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 6)),
    ($) async {
      final visualReadyMarker = File(
        '${Directory.systemTemp.path}/$_visualReadyMarkerName',
      );
      addTearDown(() async {
        if (await visualReadyMarker.exists()) {
          await visualReadyMarker.delete();
        }
        await ReportPersistenceService.clearDiagnostic();
      });
      if (await visualReadyMarker.exists()) {
        await visualReadyMarker.delete();
      }

      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1985,
        'q_residence_permit': 'G',
      });

      await $.pumpWidgetAndSettle(const MintApp());

      // Keep Patrol attached to the instrumented MintApp. The root router
      // exercises the real production route without relying on a mock shell.
      testOnlyRootRouter.go('/segments/frontalier');
      await $.pumpAndSettle();

      await $(
        find.byKey(const Key('frontier_jurisdiction_missing_state')),
      ).scrollTo();
      await $(
        find.byKey(const Key('frontier_jurisdiction_missing_state')),
      ).waitUntilVisible();
      expect(
        find.byKey(const Key('frontier_jurisdiction_known_state')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('frontier_tax_orientation_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('frontier_social_insurance_card')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('frontier_work_canton_field')),
        findsNothing,
      );

      final materialApp = find.byType(MaterialApp);
      expect(materialApp, findsOneWidget);
      final provider =
          $.tester.element(materialApp).read<CoachProfileProvider>();
      expect(provider.profile, isNotNull);
      expect(provider.profile!.residenceCountry, isNull);
      expect(provider.profile!.workCountry, isNull);
      expect(provider.profile!.workCanton, isNull);
      expect(
        $.tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('frontier_residence_country_field')),
            )
            .value,
        isNull,
      );
      expect(
        $.tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('frontier_work_country_field')),
            )
            .value,
        isNull,
      );

      await $(
        find.byKey(const Key('frontier_residence_country_field')),
      ).scrollTo();
      await $(
        find.byKey(const Key('frontier_residence_country_field')),
      ).tap();
      await $.pumpAndSettle();
      await $(_countryOverlayOption('FR')).waitUntilVisible();
      await $(_countryOverlayOption('FR')).tap();
      await $.pumpAndSettle();

      expect(
        $.tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('frontier_residence_country_field')),
            )
            .value,
        'FR',
      );
      expect(
        find.byKey(const Key('frontier_jurisdiction_missing_state')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('frontier_work_canton_field')),
        findsNothing,
      );

      await $(
        find.byKey(const Key('frontier_work_country_field')),
      ).scrollTo();
      await $(
        find.byKey(const Key('frontier_work_country_field')),
      ).tap();
      await $.pumpAndSettle();
      await $(_countryOverlayOption('CH')).waitUntilVisible();
      await $(_countryOverlayOption('CH')).tap();
      await $.pumpAndSettle();

      expect(
        $.tester
            .widget<DropdownButton<String>>(
              find.byKey(const Key('frontier_work_country_field')),
            )
            .value,
        'CH',
      );
      await $(
        find.byKey(const Key('frontier_work_canton_field')),
      ).waitUntilVisible();
      expect(
        find.byKey(const Key('frontier_jurisdiction_missing_state')),
        findsOneWidget,
      );

      await $(
        find.byKey(const Key('frontier_work_canton_field')),
      ).scrollTo();
      await $(
        find.byKey(const Key('frontier_work_canton_field')),
      ).tap();
      await $.pumpAndSettle();
      await $(_cantonOverlayOption('GE')).waitUntilVisible();
      await $(_cantonOverlayOption('GE')).tap();
      await $.pumpAndSettle();

      await $(
        find.byKey(const Key('frontier_jurisdiction_known_state')),
      ).scrollTo();
      await $(
        find.byKey(const Key('frontier_jurisdiction_known_state')),
      ).waitUntilVisible();
      await $(
        find.byKey(const Key('frontier_tax_orientation_card')),
      ).scrollTo();
      await $(
        find.byKey(const Key('frontier_tax_orientation_card')),
      ).waitUntilVisible();
      await $(
        find.byKey(const Key('frontier_social_insurance_card')),
      ).scrollTo();
      await $(
        find.byKey(const Key('frontier_social_insurance_card')),
      ).waitUntilVisible();
      expect(
        find.byKey(const Key('frontier_tax_orientation_card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('frontier_social_insurance_card')),
        findsOneWidget,
      );

      final profile = provider.profile;
      expect(profile, isNotNull);
      expect(profile!.residenceCountry?.value, 'FR');
      expect(profile.workCountry?.value, 'CH');
      expect(profile.workCanton?.value, 'GE');
      for (final path in const <String>[
        'residenceCountry',
        'workCountry',
        'workCanton',
      ]) {
        expect(profile.userProvidedFields, contains(path), reason: path);
        expect(
          profile.dataSources[path],
          ProfileDataSource.userInput,
          reason: path,
        );
        expect(profile.dataTimestamps[path], isNotNull, reason: path);
        expect(profile.dataSourceDates, contains(path), reason: path);
      }

      Map<String, dynamic> persisted = const <String, dynamic>{};
      for (var attempt = 0; attempt < 80; attempt++) {
        persisted = await ReportPersistenceService.loadAnswers();
        if (persisted['q_residence_country'] == 'FR' &&
            persisted['q_work_country'] == 'CH' &&
            persisted['q_work_canton'] == 'GE') {
          break;
        }
        await $.tester.pump(const Duration(milliseconds: 100));
      }
      expect(persisted['q_residence_country'], 'FR');
      expect(persisted['q_work_country'], 'CH');
      expect(persisted['q_work_canton'], 'GE');

      final renderedText = $.tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data ?? '')
          .join(' ');
      expect(renderedText, contains('1966'));
      expect(
        renderedText,
        isNot(matches(RegExp(r'(?:CHF|EUR|Fr\.)\s*[0-9]'))),
      );
      expect(
        renderedText.toLowerCase(),
        isNot(
          matches(
            RegExp(r'90\s+(?:jours|days|tage|días|giorni|dias)'),
          ),
        ),
      );

      await visualReadyMarker.writeAsString(
        _visualReadyMarkerPayload,
        flush: true,
      );
      final visualAcknowledgementDeadline = DateTime.now().add(
        const Duration(seconds: 90),
      );
      while (await visualReadyMarker.exists()) {
        if (DateTime.now().isAfter(visualAcknowledgementDeadline)) {
          fail('Timed out waiting for visual evidence acknowledgement');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    },
  );
}
