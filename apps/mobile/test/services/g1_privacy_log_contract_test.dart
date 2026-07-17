import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('G1 production logs never interpolate financial or memory payloads', () {
    final memory = File(
      'lib/services/memory/coach_memory_service.dart',
    ).readAsStringSync();
    final notifications = File(
      'lib/services/notifications_wiring_service.dart',
    ).readAsStringSync();
    final financialPlanSetup = File(
      'lib/widgets/coach/financial_plan_setup_card.dart',
    ).readAsStringSync();
    final regulatorySync = File(
      'lib/services/regulatory_sync_service.dart',
    ).readAsStringSync();
    String debugCalls(String source) => RegExp(
          r'debugPrint\([\s\S]*?\);',
        ).allMatches(source).map((match) => match.group(0)!).join('\n');
    final memoryLogs = debugCalls(memory);
    final notificationLogs = debugCalls(notifications);
    final financialPlanLogs = debugCalls(financialPlanSetup);
    final regulatoryLogs = debugCalls(regulatorySync);

    for (final raw in const <String>{
      r'$error',
      r'$stackTrace',
      r'$insightId',
      r'$topic',
    }) {
      expect(memoryLogs, isNot(contains(raw)),
          reason: 'CoachMemory leaks $raw');
    }
    for (final raw in const <String>{
      r'triad=$signature',
      r'$e',
      r'$st',
    }) {
      expect(
        notificationLogs,
        isNot(contains(raw)),
        reason: 'NotificationsWiring leaks $raw',
      );
    }
    for (final raw in const <String>{r'$error', r'$stackTrace'}) {
      expect(
        financialPlanLogs,
        isNot(contains(raw)),
        reason: 'FinancialPlanSetup leaks $raw',
      );
    }
    for (final raw in const <String>{
      r'$e',
      r'$key',
      r'$error',
      r'$stackTrace'
    }) {
      expect(
        regulatoryLogs,
        isNot(contains(raw)),
        reason: 'RegulatorySync leaks $raw',
      );
    }
  });

  test('remote hydration has one guarded canonical production entry point', () {
    final provider = File(
      'lib/providers/coach_profile_provider.dart',
    ).readAsStringSync();

    expect(provider, contains('Future<void> mergeBackendUnknownProfile('));
    expect(provider, isNot(contains('void createFromRemoteProfile(')));
  });

  test('financial plan persistence exposes no callerless rollback facade', () {
    final service = File(
      'lib/services/financial_plan_service.dart',
    ).readAsStringSync();

    expect(service, isNot(contains('captureSnapshot')));
    expect(service, isNot(contains('restoreSnapshot')));
    expect(service, isNot(contains('FinancialPlanStorageSnapshot')));
  });
}
