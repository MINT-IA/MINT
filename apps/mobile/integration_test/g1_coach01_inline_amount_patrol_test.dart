import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/services/coach/coach_orchestrator.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/widgets/coach/chat_inline_inputs.dart';
import 'package:mint_mobile/widgets/coach/coach_input_bar.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');
const _question = 'Question salariale synthétique';
const _annualSalary = '120000';
const _salaryEcho = "Salaire brut annuel déclaré : CHF 120'000";
const _visualReadyMarkerName = 'mint-g1-coach01-visual-ready-v1.marker';
const _visualReadyMarkerPayload = 'MINT_G1_COACH01_VISUAL_READY_V1\n';

void main() {
  patrolTest(
    'persists the real inline salary picker and cold-reloads its provenance',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 6)),
    ($) async {
      final visualReadyMarker = File(
        '${Directory.systemTemp.path}/$_visualReadyMarkerName',
      );
      final previousSlmNarratives = FeatureFlags.enableSlmNarratives;
      FeatureFlags.enableSlmNarratives = false;
      FeatureFlags.typedLppEvidence = false;
      addTearDown(() async {
        if (await visualReadyMarker.exists()) {
          await visualReadyMarker.delete();
        }
        FeatureFlags.enableSlmNarratives = previousSlmNarratives;
        FeatureFlags.typedLppEvidence = false;
        CoachLlmService.registerOrchestrator(CoachOrchestrator.generateChat);
      });
      if (await visualReadyMarker.exists()) {
        await visualReadyMarker.delete();
      }

      await ReportPersistenceService.clearDiagnostic();
      await ReportPersistenceService.setMiniOnboardingCompleted(true);
      await ReportPersistenceService.saveAnswers(<String, dynamic>{
        'q_birth_year': 1990,
        'q_canton': 'VD',
        'q_nombre_mois': 12,
        'q_net_income_period_chf': 6500.0,
        'q_pay_frequency': 'monthly',
      });

      final liveProvider = CoachProfileProvider();
      await liveProvider.loadFromWizard();
      var responseCount = 0;
      CoachLlmService.registerOrchestrator(({
        required userMessage,
        required history,
        required ctx,
        byokConfig,
        memoryBlock,
        language = 'fr',
        cashLevel = 3,
      }) async {
        responseCount += 1;
        if (responseCount == 1) {
          expect(userMessage, _question);
          return const CoachResponse(
            message: 'Saisis le montant annuel synthétique.',
            disclaimer: '',
            toolCalls: <RagToolCall>[
              RagToolCall(
                name: 'ask_user_input',
                input: <String, dynamic>{
                  'field_key': 'salaireBrut',
                  'prompt_text': 'Salaire brut annuel synthétique',
                },
              ),
            ],
          );
        }
        if (responseCount == 2) {
          expect(userMessage, _salaryEcho);
          return const CoachResponse(
            message: 'Écriture synthétique terminée.',
            disclaimer: '',
          );
        }
        throw StateError('Unexpected synthetic Coach invocation');
      });

      final router = GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, __) => const CoachChatScreen(),
          ),
        ],
      );
      await $.pumpWidgetAndSettle(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CoachProfileProvider>.value(
              value: liveProvider,
            ),
            ChangeNotifierProvider<ByokProvider>(
              create: (_) => ByokProvider(),
            ),
            ChangeNotifierProvider<MintStateProvider>(
              create: (_) => MintStateProvider(),
            ),
            ChangeNotifierProvider<AuthProvider>(
              create: (_) => AuthProvider(),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('fr'),
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
          ),
        ),
      );

      final coachInput = find.descendant(
        of: find.byType(CoachInputBar),
        matching: find.byType(TextField),
      );
      await $(coachInput).waitUntilVisible();
      await $(coachInput).enterText(_question);
      await $(find.byIcon(Icons.arrow_upward_rounded)).tap();

      final amountPicker = find.byType(ChatAmountInput);
      await $(amountPicker).waitUntilVisible();
      final amountField = find.descendant(
        of: amountPicker,
        matching: find.byType(TextField),
      );
      final submit = find.descendant(
        of: amountPicker,
        matching: find.byType(FilledButton),
      );
      await $(amountField).enterText(_annualSalary);
      await $(submit).scrollTo().tap();

      await $(find.text(_salaryEcho)).waitUntilVisible();
      await $(find.text('Écriture synthétique terminée.')).waitUntilVisible();
      expect(find.byType(ChatAmountInput), findsNothing);
      expect(responseCount, 2);

      final persisted = await ReportPersistenceService.loadAnswers();
      expect(persisted['q_gross_salary_annual'], 120000.0);
      expect(persisted['q_nombre_mois'], 12);

      final coldProvider = CoachProfileProvider();
      await coldProvider.loadFromWizard();
      final coldProfile = coldProvider.profile;
      expect(coldProfile, isNotNull);
      expect(coldProfile!.salaireBrutMensuel, closeTo(10000, 0.000001));
      expect(
        coldProfile.dataSources['salaireBrutMensuel'],
        ProfileDataSource.userInput,
      );
      expect(coldProfile.dataTimestamps['salaireBrutMensuel'], isNotNull);
      expect(coldProfile.dataSourceDates, contains('salaireBrutMensuel'));
      expect(coldProfile.dataSourceDates['salaireBrutMensuel'], isNull);

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
