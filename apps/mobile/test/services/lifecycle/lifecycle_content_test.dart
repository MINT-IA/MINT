import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_content_service.dart';
import 'package:mint_mobile/services/lifecycle/lifecycle_phase.dart';

// ────────────────────────────────────────────────────────────
//  LIFECYCLE CONTENT SERVICE TESTS — S57
// ────────────────────────────────────────────────────────────
//
// 15 tests covering:
//   - phaseLabel: non-empty for every phase, uses i18n (no hardcoded text)
//   - phaseDescription: non-empty for every phase
//   - suggestedTopics: non-empty list for every phase
//   - suggestedTopics: known intent tags cross-checked by phase
//   - No duplicate intent tags within a phase
// ────────────────────────────────────────────────────────────

/// French localizations — no BuildContext needed in unit tests.
final _l = SFr();

void main() {
  // ══════════════════════════════════════════════════════════════
  //  phaseLabel — i18n labels
  // ══════════════════════════════════════════════════════════════

  group('LifecycleContentService.phaseLabel', () {
    test('returns non-empty label for every phase', () {
      for (final phase in LifecyclePhase.values) {
        final label = LifecycleContentService.phaseLabel(phase, _l);
        expect(label, isNotEmpty, reason: 'phase $phase has empty label');
      }
    });

    test('demarrage label is "Démarrage" (French)', () {
      expect(
        LifecycleContentService.phaseLabel(LifecyclePhase.demarrage, _l),
        equals('Démarrage'),
      );
    });

    test('all 7 phases produce distinct labels', () {
      final labels = LifecyclePhase.values
          .map((p) => LifecycleContentService.phaseLabel(p, _l))
          .toList();
      final uniqueLabels = labels.toSet();
      expect(
        uniqueLabels.length,
        equals(LifecyclePhase.values.length),
        reason: 'Phase labels must be distinct — found duplicates: $labels',
      );
    });

    test('consolidation label is "Consolidation" (French)', () {
      expect(
        LifecycleContentService.phaseLabel(LifecyclePhase.consolidation, _l),
        equals('Consolidation'),
      );
    });

    test('retraite label is "Retraite" (French)', () {
      expect(
        LifecycleContentService.phaseLabel(LifecyclePhase.retraite, _l),
        equals('Retraite'),
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  phaseDescription — i18n descriptions
  // ══════════════════════════════════════════════════════════════

  group('LifecycleContentService.phaseDescription', () {
    test('returns non-empty description for every phase', () {
      for (final phase in LifecyclePhase.values) {
        final desc = LifecycleContentService.phaseDescription(phase, _l);
        expect(desc, isNotEmpty, reason: 'phase $phase has empty description');
      }
    });

    test('all 7 phases produce distinct descriptions', () {
      final descs = LifecyclePhase.values
          .map((p) => LifecycleContentService.phaseDescription(p, _l))
          .toList();
      final uniqueDescs = descs.toSet();
      expect(
        uniqueDescs.length,
        equals(LifecyclePhase.values.length),
        reason: 'Phase descriptions must be distinct',
      );
    });

    test('demarrage description mentions 3a', () {
      final desc =
          LifecycleContentService.phaseDescription(LifecyclePhase.demarrage, _l);
      expect(desc.toLowerCase(), contains('3a'));
    });

    test('consolidation description mentions retraite or LPP', () {
      final desc =
          LifecycleContentService.phaseDescription(LifecyclePhase.consolidation, _l);
      final lower = desc.toLowerCase();
      expect(
        lower.contains('retraite') || lower.contains('lpp'),
        isTrue,
        reason: 'consolidation description should mention retraite or lpp',
      );
    });
  });

  // ══════════════════════════════════════════════════════════════
  //  suggestedTopics — intent tags
  // ══════════════════════════════════════════════════════════════

  group('LifecycleContentService.suggestedTopics', () {
    test('returns non-empty list for every phase', () {
      for (final phase in LifecyclePhase.values) {
        final topics = LifecycleContentService.suggestedTopics(phase);
        expect(topics, isNotEmpty, reason: 'phase $phase has no suggestedTopics');
      }
    });

    test('no duplicate intent tags within a single phase', () {
      for (final phase in LifecyclePhase.values) {
        final topics = LifecycleContentService.suggestedTopics(phase);
        final unique = topics.toSet();
        expect(
          unique.length,
          equals(topics.length),
          reason: 'phase $phase has duplicate intent tags: $topics',
        );
      }
    });

    test('all intent tags are snake_case strings', () {
      final snakeCaseRegex = RegExp(r'^[a-z][a-z0-9_]*$');
      for (final phase in LifecyclePhase.values) {
        for (final tag in LifecycleContentService.suggestedTopics(phase)) {
          expect(
            snakeCaseRegex.hasMatch(tag),
            isTrue,
            reason: 'intent tag "$tag" in phase $phase is not snake_case',
          );
        }
      }
    });

    test('demarrage includes budget_overview and pillar_3a_intro', () {
      final topics = LifecycleContentService.suggestedTopics(LifecyclePhase.demarrage);
      expect(topics, contains('budget_overview'));
      expect(topics, contains('pillar_3a_intro'));
    });

    test('consolidation includes lpp_deep and rente_vs_capital', () {
      final topics = LifecycleContentService.suggestedTopics(LifecyclePhase.consolidation);
      expect(topics, contains('lpp_deep'));
      expect(topics, contains('rente_vs_capital'));
    });

    test('transition includes withdrawal_sequencing', () {
      final topics = LifecycleContentService.suggestedTopics(LifecyclePhase.transition);
      expect(topics, contains('withdrawal_sequencing'));
    });

    test('transmission includes succession', () {
      final topics = LifecycleContentService.suggestedTopics(LifecyclePhase.transmission);
      expect(topics, contains('succession'));
    });

    test('retraite includes budget_overview', () {
      final topics = LifecycleContentService.suggestedTopics(LifecyclePhase.retraite);
      expect(topics, contains('budget_overview'));
    });

    test('acceleration includes lpp_deep and monte_carlo', () {
      final topics = LifecycleContentService.suggestedTopics(LifecyclePhase.acceleration);
      expect(topics, contains('lpp_deep'));
      expect(topics, contains('monte_carlo'));
    });
  });
}
