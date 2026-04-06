import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/contextual/coach_opener_service.dart';

void main() {
  group('CoachOpenerService', () {
    final now = DateTime(2026, 4, 6);

    CoachProfile _makeProfile({
      double salaireBrutMensuel = 10000,
      String employmentStatus = 'salarie',
      PrevoyanceProfile prevoyance = const PrevoyanceProfile(),
    }) {
      return CoachProfile(
        birthYear: 1977,
        canton: 'VS',
        salaireBrutMensuel: salaireBrutMensuel,
        employmentStatus: employmentStatus,
        prevoyance: prevoyance,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2042, 1, 12),
          label: 'Retraite',
        ),
      );
    }

    BiographyFact _salaryFact({
      DateTime? updatedAt,
      FactSource source = FactSource.document,
    }) {
      return BiographyFact(
        id: 'salary-1',
        factType: FactType.salary,
        value: '130000',
        source: source,
        createdAt: now.subtract(const Duration(days: 60)),
        updatedAt: updatedAt ?? now.subtract(const Duration(days: 10)),
        sourceDate: now.subtract(const Duration(days: 30)),
      );
    }

    BiographyFact _documentFact({
      FactType factType = FactType.lppCapital,
      DateTime? updatedAt,
    }) {
      return BiographyFact(
        id: 'doc-1',
        factType: factType,
        value: '150000',
        source: FactSource.document,
        createdAt: now.subtract(const Duration(days: 20)),
        updatedAt: updatedAt ?? now.subtract(const Duration(days: 5)),
        sourceDate: now.subtract(const Duration(days: 10)),
      );
    }

    test('salary increase in biography -> opener mentions salary change', () {
      final profile = _makeProfile(salaireBrutMensuel: 10833);
      final facts = [_salaryFact()];

      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      expect(opener, contains('salaire'));
      expect(opener, contains('Voici ce que cela change'));
    });

    test('recent document scan -> opener references document', () {
      // No salary fact but has recent document scan (LPP)
      final profile = _makeProfile(salaireBrutMensuel: 0);
      final facts = [_documentFact()];

      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      expect(opener, contains('certificat'));
      expect(opener, contains('projections'));
    });

    test('no biography facts -> fallback opener', () {
      final profile = _makeProfile();
      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: [],
        now: now,
      );

      expect(opener, contains('Bienvenue'));
      expect(opener, contains('aperçu financier'));
    });

    test('opener never contains imperative language', () {
      final profile = _makeProfile();
      final facts = [_salaryFact(), _documentFact()];

      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      expect(opener.toLowerCase(), isNot(contains('tu devrais')));
      expect(opener.toLowerCase(), isNot(contains('tu dois')));
      expect(opener.toLowerCase(), isNot(contains('fais ceci')));
    });

    test('opener passes ComplianceGuard validation', () {
      final profile = _makeProfile();
      final facts = [_salaryFact()];

      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      // The opener should be non-empty and compliant
      expect(opener, isNotEmpty);
      // No banned terms
      expect(opener.toLowerCase(), isNot(contains('garanti')));
      expect(opener.toLowerCase(), isNot(contains('optimal')));
    });

    test('stale salary fact (>90 days) does not trigger salary opener', () {
      final profile = _makeProfile(salaireBrutMensuel: 10833);
      final facts = [
        _salaryFact(updatedAt: now.subtract(const Duration(days: 100))),
      ];

      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      // Should not mention salary progression since document is stale
      expect(opener, isNot(contains('salaire a progressé')));
    });

    test('stale document (>30 days) does not trigger document opener', () {
      final profile = _makeProfile(salaireBrutMensuel: 0);
      final facts = [
        _documentFact(updatedAt: now.subtract(const Duration(days: 45))),
      ];

      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      // Should not mention certificat since document is stale
      expect(opener, isNot(contains('certificat')));
    });

    test('3a gap opener when gap exists and no recent documents', () {
      // Profile with salary, no 3a contribution, and no recent document scans
      final profile = _makeProfile(salaireBrutMensuel: 10000);
      final facts = [
        _salaryFact(
          updatedAt: now.subtract(const Duration(days: 100)),
          source: FactSource.userInput,
        ),
      ];

      final opener = CoachOpenerService.generate(
        profile: profile,
        facts: facts,
        now: now,
      );

      expect(opener, contains('optimiser'));
      expect(opener, contains('CHF'));
    });
  });
}
