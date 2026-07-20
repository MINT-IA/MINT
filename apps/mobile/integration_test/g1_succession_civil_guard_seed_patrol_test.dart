import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:patrol/patrol.dart';

const _runningFromPatrolCli = bool.fromEnvironment('MINT_PATROL_CLI');

void main() {
  patrolTest(
    'seeds ambiguous legacy civil status without completing onboarding',
    skip: !_runningFromPatrolCli,
    timeout: const Timeout(Duration(minutes: 2)),
    ($) async {
      await ReportPersistenceService.clearDiagnostic();
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );
      await ReportPersistenceService.saveAnswers(const {
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_civil_status': 'partenariat',
      });

      final persisted = await ReportPersistenceService.loadAnswers();
      expect(persisted['q_civil_status'], 'partenariat');
      expect(
        await ReportPersistenceService.isMiniOnboardingCompleted(),
        isFalse,
      );

      final rehydrated = CoachProfile.fromWizardAnswers(persisted);
      expect(rehydrated.civilStatusNeedsConfirmation, isTrue);
    },
  );
}
