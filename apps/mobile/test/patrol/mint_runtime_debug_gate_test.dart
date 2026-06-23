import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/app.dart';
import 'package:mint_mobile/data/budget/budget_local_store.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/admin/mint_debug_spine_screen.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/anonymous_session_service.dart';
import 'package:mint_mobile/services/coach/conversation_store.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';
import 'package:mint_mobile/services/debug/mint_debug_spine_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:patrol/patrol.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart' hide Selector;
import 'package:shared_preferences/shared_preferences.dart';

const _runningFromPatrolCli = bool.hasEnvironment('PATROL_APP_BUNDLE_ID') ||
    bool.hasEnvironment('PATROL_TEST_LABEL') ||
    bool.hasEnvironment('PATROL_WAIT');

const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
const _adminFlag = String.fromEnvironment(
  'ENABLE_ADMIN',
  defaultValue: 'false',
);
const _debugToolsFlag = String.fromEnvironment(
  'ENABLE_DEBUG_TOOLS',
  defaultValue: 'false',
);
const _adminEnabled = _adminFlag == 'true' || _adminFlag == '1';
const _debugToolsEnabled = _debugToolsFlag == 'true' || _debugToolsFlag == '1';
const _disableBetaModal = bool.fromEnvironment('MINT_DISABLE_BETA_MODAL');
const _mint2FirstExperience =
    bool.fromEnvironment('MINT_E2E_MINT2_FIRST_EXPERIENCE');
const _proofAnchors = bool.fromEnvironment('MINT_E2E_PROOF_ANCHORS');
const _runtimeDebugEvidence =
    bool.fromEnvironment('MINT_RUNTIME_DEBUG_EVIDENCE');
const _runtimeDebugLeg = String.fromEnvironment(
  'MINT_RUNTIME_DEBUG_LEG',
  defaultValue: 'reset',
);
const _runtimeDebugRunId = String.fromEnvironment(
  'MINT_RUNTIME_DEBUG_RUN_ID',
  defaultValue: 'manual',
);
const _runtimeDebugForegroundHoldSeconds = int.fromEnvironment(
  'MINT_RUNTIME_DEBUG_FOREGROUND_HOLD_SECONDS',
);

const _syntheticPublicAnswer = '__MINT_SYNTHETIC_PLAN02_PUBLIC__';
const _syntheticSensitiveAnswer = '__MINT_SYNTHETIC_PLAN02_SENSITIVE__';
const _syntheticChatBody = '__MINT_SYNTHETIC_PLAN02_CHAT_BODY__';
const _syntheticContact = '__MINT_SYNTHETIC_PLAN02_CONTACT__';
const _syntheticNetIncome = -920000001.0;
const _syntheticHousingCost = -920000002.0;
const _syntheticBudgetOverride = -0.920000003;
const _foregroundBoundaryKey =
    ValueKey<String>('mint_runtime_debug_foreground_boundary');

void main() {
  patrolTest(
    'proves fresh reset relaunch redacted Debug Spine evidence',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 3)),
    ($) async {
      expect(_apiBaseUrl, isNotEmpty);
      expect(_disableBetaModal, isTrue);
      expect(_mint2FirstExperience, isTrue);
      expect(_proofAnchors, isTrue);
      expect(_adminEnabled, isTrue);
      expect(_debugToolsEnabled, isTrue);
      expect(_runtimeDebugEvidence, isTrue);
      expect(['reset', 'relaunch'], contains(_runtimeDebugLeg));

      FeatureFlags.applyRuntimeOverrides();
      MintHttpClient.configureRuntimeDebugEvidence(enabled: true);

      // Patrol docs require pumping the app widget instead of calling main().
      // main() owns runApp/Sentry/error-boundary setup that hides test failures.
      await $.pumpWidgetAndSettle(const MintApp());

      if (_runtimeDebugLeg == 'reset') {
        await _seedSyntheticResidue();
        final beforeSnapshot = await MintDebugSpineService.loadSnapshot();
        final before = beforeSnapshot.toRedactedJson();
        await _emitEvidence('before_reset', before);
        _assertRedactedEvidence(before);
        expect(beforeSnapshot.hasLocalResidue, isTrue);

        final afterSnapshot = await MintDebugSpineService.resetProfileStores(
          CoachProfileProvider(),
        );
        final after = afterSnapshot.toRedactedJson();
        await _emitEvidence('after_reset', after);
        _assertRedactedEvidence(after);
        _assertCleanSnapshot(afterSnapshot);
        return;
      }

      final redacted = await MintDebugSpineService.loadRedactedJson();
      final relaunchSnapshot = await MintDebugSpineService.loadSnapshot();
      await _emitEvidence('after_relaunch', redacted);
      _assertRedactedEvidence(redacted);

      expect(redacted['schemaVersion'], MintDebugSpineSnapshot.schemaVersion);
      final residue = redacted['residue']! as Map<String, Object?>;
      expect(residue.keys, contains('wizardAnswers'));
      expect(residue.keys, contains('budgetInputs'));
      expect(residue.keys, contains('networkSummary'));
      _assertCleanSnapshot(relaunchSnapshot);

      await _pumpDebugSpineForeground($);
    },
  );
}

Future<void> _seedSyntheticResidue() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'wizard_answers_v2',
    json.encode({
      'q_public_debug_marker': _syntheticPublicAnswer,
      'q_net_income_period_chf': _syntheticSensitiveAnswer,
      'q_firstname': _syntheticContact,
    }),
  );
  await BudgetLocalStore().saveInputs(
    const BudgetInputs(
      payFrequency: PayFrequency.monthly,
      netIncome: _syntheticNetIncome,
      housingCost: _syntheticHousingCost,
      debtPayments: 0,
    ),
  );
  await BudgetLocalStore().saveOverride(
    'plan02_runtime_debug',
    _syntheticBudgetOverride,
  );
  await AnonymousSessionService.updateFromResponse(1);
  ConversationStore.setCurrentUserId(null);
  await ConversationStore().saveConversation('plan02-anon-conversation', [
    ChatMessage(
      role: 'user',
      content: _syntheticChatBody,
      timestamp: DateTime(2026, 6, 22, 17),
    ),
  ]);
  ConversationStore.setCurrentUserId('plan02-runtime-user');
  await ConversationStore().saveConversation('plan02-user-conversation', [
    ChatMessage(
      role: 'user',
      content: _syntheticChatBody,
      timestamp: DateTime(2026, 6, 22, 17, 1),
    ),
  ]);
  await AccountHandoffService.saveChoice(
    AccountHandoffChoice.keepLocal,
    now: DateTime(2026, 6, 22, 17, 2),
  );
  expect(
    (await MintDebugSpineService.loadSnapshot()).accountHandoffChoice,
    'keep_local',
  );
  await AccountHandoffService.saveChoice(
    AccountHandoffChoice.restartClean,
    now: DateTime(2026, 6, 22, 17, 3),
  );
  await prefs.setString('local_data_owner', 'plan02-runtime-user');
  await prefs.setBool('local_data_migrated_plan02-runtime-user', true);
  await prefs.setBool('local_data_sync_pending_plan02-runtime-user', true);
  await prefs.setBool('auth_local_mode', true);
}

Future<void> _emitEvidence(String label, Map<String, Object?> redacted) async {
  await MintDebugSpineService.writeRedactedEvidence(label, redacted);
}

Future<void> _pumpDebugSpineForeground(PatrolIntegrationTester $) async {
  final semantics = $.tester.ensureSemantics();

  try {
    await $.tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CoachProfileProvider(),
        child: const MaterialApp(
          home: RepaintBoundary(
            key: _foregroundBoundaryKey,
            child: Scaffold(body: MintDebugSpineScreen()),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 20; attempt += 1) {
      await $.tester.pump(const Duration(milliseconds: 250));
    }

    expect(find.text('Debug spine'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mint_debug_spine_snapshot')),
      findsOneWidget,
    );
    await _writeForegroundArtifacts($);

    // ignore: avoid_print
    print(
        'MINT_RUNTIME_DEBUG_FOREGROUND_READY Debug spine mint_debug_spine_snapshot');

    if (_runtimeDebugForegroundHoldSeconds > 0) {
      await Future<void>.delayed(
        const Duration(seconds: _runtimeDebugForegroundHoldSeconds),
      );
    }
  } finally {
    semantics.dispose();
  }
}

Future<void> _writeForegroundArtifacts(PatrolIntegrationTester $) async {
  final supportDir = await getApplicationSupportDirectory();
  final evidenceDir = Directory(
    '${supportDir.path}/mint-runtime-debug-evidence',
  );
  await evidenceDir.create(recursive: true);

  final snapshot = await MintDebugSpineService.loadSnapshot();
  final uiTreeJson = [
    {
      'text': 'Debug spine',
      'identifier': 'mint_debug_spine_title',
      'source': 'patrol_debug_spine_redacted_rows',
    },
    {
      'text': snapshot.redactedRows.join('; '),
      'identifier': 'mint_debug_spine_snapshot',
      'source': 'patrol_debug_spine_redacted_rows',
    },
  ];
  await File('${evidenceDir.path}/ui-tree.json').writeAsString(
    json.encode(uiTreeJson),
  );
  await File('${evidenceDir.path}/ui-tree.txt').writeAsString(
    '${[
      'Debug spine',
      'mint_debug_spine_snapshot',
      ...snapshot.redactedRows,
    ].join('\n')}\n',
  );
  await File('${evidenceDir.path}/foreground-proof.txt').writeAsString(
    'run_id: $_runtimeDebugRunId\n'
    'foreground: ch.mint.app\n'
    'route_surface: MintDebugSpineScreen\n'
    'anchor: mint_debug_spine_snapshot\n'
    'capture_source: patrol_debug_spine_redacted_rows\n'
    'os_native_foreground: not_proven\n'
    'springboard_rejected: true\n',
  );

  final boundary = $.tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_foregroundBoundaryKey),
  );
  final image = await boundary.toImage(pixelRatio: 2);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final bytes = byteData!.buffer.asUint8List();
  await File('${evidenceDir.path}/final-reset-state.png').writeAsBytes(bytes);
}

void _assertCleanSnapshot(MintDebugSpineSnapshot snapshot) {
  expect(snapshot.hasWizardAnswers, isFalse);
  expect(snapshot.hasCorruptWizardAnswers, isFalse);
  expect(snapshot.wizardAnswerKeyCount, 0);
  expect(snapshot.plainSensitiveWizardKeyCount, 0);
  expect(snapshot.hasBudgetInputs, isFalse);
  expect(snapshot.hasCorruptBudgetInputs, isFalse);
  expect(snapshot.hasBudgetOverrides, isFalse);
  expect(snapshot.anonymousMessageCount, 0);
  expect(snapshot.conversationCount, 0);
  expect(snapshot.anonymousConversationCount, 0);
  expect(snapshot.currentUserConversationCount, 0);
  expect(snapshot.hasHeldAnonymousDiagnostic, isFalse);
  expect(snapshot.accountHandoffChoice, 'none');
  expect(snapshot.hasLocalDataOwner, isFalse);
  expect(snapshot.localDataMigratedFlagCount, 0);
  expect(snapshot.localDataSyncPendingFlagCount, 0);
  expect(snapshot.cloudSyncLocalMode, isFalse);
  expect(snapshot.installSecurePurgePending, isA<bool>());
  expect(snapshot.ownedSecurePurgePending, isA<bool>());
  expect(snapshot.networkSummary['status'], 'recording');
  expect(snapshot.networkSummary['forbiddenMatchCount'], 0);
  expect(snapshot.networkSummary['entries'], isA<List<Object?>>());
}

void _assertRedactedEvidence(Map<String, Object?> redacted) {
  final encoded = json.encode(redacted);
  for (final forbidden in [
    _syntheticPublicAnswer,
    _syntheticSensitiveAnswer,
    _syntheticChatBody,
    _syntheticContact,
    _syntheticNetIncome.toString(),
    _syntheticHousingCost.toString(),
    _syntheticBudgetOverride.toString(),
    'q_public_debug_marker',
    'q_net_income_period_chf',
    'q_firstname',
    'plan02-runtime-user',
    'plan02-anon-conversation',
    'plan02-user-conversation',
    'Authorization',
    'authorization',
    'Bearer',
    'bearer',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    '@',
    'CHF',
  ]) {
    expect(encoded, isNot(contains(forbidden)));
  }
}
