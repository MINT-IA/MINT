// Phase 01.5 Wave 02 Plan 06 — coach_profile_seeds_test.dart.
//
// Locks the walker seed registry contract:
//   1. The new `julien_expat_us` seed exists and carries the FATCA
//      archetype-discriminating signals (usTaxPerson:true, nationality:'US',
//      archetype slug 'expat_us').
//   2. The 4 v2.10 swiss_native seeds (julien_swiss, couple_acheteurs_lausanne,
//      jeune_diplome_zurich, cadre_40_55_lpp_rachat) are NOT modified.
//   3. The new `byArchetype(slug)` helper maps archetype slugs to seed names
//      (Codex C3 MEDIUM fix — REVIEWS.md 2026-05-22). The walker's Maestro
//      flow (Wave 03 plan 01) passes `--dart-define=MINT_E2E_ARCHETYPE=<slug>`
//      using the ARCHETYPE slug (e.g. 'expat_us'), NOT the seed name (e.g.
//      'julien_expat_us'). This contract makes the mapping explicit so a
//      typo in the slug surfaces as null (callers MUST handle) rather than
//      silently routing to no seed.
//
// References:
//   - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-02-06-PLAN.md
//   - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-REVIEWS.md §C3

import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/data_spine/coach_context_packet_adapter.dart';

void main() {
  group('CoachProfileSeeds — julien_expat_us (Wave 02 plan 06)', () {
    test('seed_registry_contains_julien_expat_us', () {
      final seed = CoachProfileSeeds.registry['julien_expat_us'];
      expect(seed, isNotNull,
          reason:
              'julien_expat_us must be present in registry to unblock Wave 03 '
              'Maestro flow (gate-firing path).');
      expect(seed!.archetype, 'expat_us',
          reason:
              'Seed archetype slug must be expat_us so the CoachProfile typed '
              'archetype getter returns FinancialArchetype.expatUs and the '
              'gate fires at coach_chat_screen.dart.');
    });

    test('seed_julien_expat_us_has_us_tax_person_true', () {
      final seed = CoachProfileSeeds.registry['julien_expat_us']!;
      expect(seed.usTaxPerson, isTrue,
          reason:
              'usTaxPerson:true is the FATCA short-circuit signal — without '
              'it the archetype getter would not return expatUs and the gate '
              'would not fire (Wave 02 plan 01 detection contract).');
    });

    test('seed_julien_expat_us_has_nationality_us', () {
      final seed = CoachProfileSeeds.registry['julien_expat_us']!;
      expect(seed.nationality, 'US',
          reason: 'nationality:"US" is the secondary archetype-discriminating '
              'signal alongside usTaxPerson; both are required for the seed '
              'to deterministically hydrate a CoachProfile that resolves to '
              'FinancialArchetype.expatUs.');
    });

    test('seed_julien_expat_us_does_not_plan_3a_contributions', () {
      final seed = CoachProfileSeeds.registry['julien_expat_us']!;
      final answers = seed.toWizardAnswers(now: DateTime(2026));
      final profile = CoachProfile.fromWizardAnswers(answers);

      expect(answers['q_has_pension_fund'], isFalse);
      expect(answers['q_has_3a'], isFalse);
      expect(answers['q_3a_annual_contribution'], 0.0);
      expect(answers['q_3a_accounts_count'], 0);
      expect(answers['q_savings_allocation'], isNot(contains('3a')),
          reason: 'FATCA/US-person seed must not create a synthetic 3a '
              'planned contribution through the savings allocation fallback.');
      expect(profile.total3aMensuel, 0);
    });

    test('existing_seeds_unchanged', () {
      // Karpathy #3 (surgical changes) — the 4 v2.10 swiss_native seeds MUST
      // NOT be modified by this plan. Regression guard.
      const expectedSwissNative = <String>{
        'julien_swiss',
        'couple_acheteurs_lausanne',
        'jeune_diplome_zurich',
        'cadre_40_55_lpp_rachat',
      };
      for (final key in expectedSwissNative) {
        final seed = CoachProfileSeeds.registry[key];
        expect(seed, isNotNull, reason: 'Existing seed $key must still exist.');
        expect(seed!.archetype, 'swiss_native',
            reason:
                'Existing seed $key must still carry archetype=swiss_native '
                '(not migrated by this plan).');
      }
    });

    test(
      'forced_archetype_slug_returns_julien_expat_us_when_dart_define_matches',
      () {
        // Compile-time constant: `MINT_E2E_ARCHETYPE` is set via dart-define.
        // When the test suite is run WITHOUT --dart-define, the constant is
        // the empty string and forcedArchetypeSlug() returns null. This test
        // asserts the registry CONTAINS the slug, which is the necessary
        // condition for the dart-define path to resolve when the walker DOES
        // pass --dart-define=MINT_E2E_ARCHETYPE=julien_expat_us.
        expect(
          CoachProfileSeeds.registry.containsKey('julien_expat_us'),
          isTrue,
          reason:
              'Required for forcedArchetypeSlug() to resolve to julien_expat_us '
              'when MINT_E2E_ARCHETYPE=julien_expat_us is passed at build time.',
        );
        // Belt-and-suspenders: bySlug helper resolves the seed name.
        final via = CoachProfileSeeds.bySlug('julien_expat_us');
        expect(via, isNotNull);
        expect(via, same(CoachProfileSeeds.registry['julien_expat_us']));
      },
    );
  });

  group('CoachProfileSeeds.byArchetype — Codex C3 MEDIUM contract', () {
    test('by_archetype_expat_us_returns_julien_expat_us_seed', () {
      // Codex C3 MEDIUM (REVIEWS.md 2026-05-22): the archetype slug 'expat_us'
      // MUST resolve to the seed 'julien_expat_us'. The walker's dart-define
      // passes the archetype slug; this contract makes the mapping explicit.
      final byArchetype = CoachProfileSeeds.byArchetype('expat_us');
      final directLookup = CoachProfileSeeds.registry['julien_expat_us'];
      expect(byArchetype, isNotNull,
          reason:
              'archetype slug expat_us MUST resolve via byArchetype helper.');
      expect(byArchetype, same(directLookup),
          reason: 'archetype slug expat_us MUST map to seed julien_expat_us. '
              'Codex C3 contract — 01.5-REVIEWS.md.');
    });

    test('by_archetype_swiss_native_returns_julien_swiss_seed', () {
      // Symmetric guard against silent contract drift if the swiss_native
      // canonical seed is ever renamed.
      final byArchetype = CoachProfileSeeds.byArchetype('swiss_native');
      final directLookup = CoachProfileSeeds.registry['julien_swiss'];
      expect(byArchetype, isNotNull);
      expect(byArchetype, same(directLookup),
          reason: 'archetype slug swiss_native MUST map to seed julien_swiss.');
    });

    test('by_archetype_independent_no_lpp_returns_runtime_fixture', () {
      final byArchetype = CoachProfileSeeds.byArchetype('independent_no_lpp');
      final directLookup =
          CoachProfileSeeds.registry['independent_no_lpp_income_reality'];

      expect(byArchetype, isNotNull,
          reason: 'The independent/no-LPP persona-flow benchmark needs a '
              'canonical runtime seed, not a salaried swiss_native fallback.');
      expect(byArchetype, same(directLookup),
          reason: 'archetype slug independent_no_lpp MUST map to the '
              'independent_no_lpp_income_reality seed.');
    });

    test('by_archetype_unknown_slug_returns_null', () {
      // Codex C3: unknown slug returns null — NOT a default seed, NOT a
      // crash. The caller (walker / Maestro flow / test) decides what to do
      // with an unmapped slug.
      expect(CoachProfileSeeds.byArchetype('not_a_real_archetype'), isNull);
      expect(CoachProfileSeeds.byArchetype(''), isNull);
    });
  });

  group('CoachProfileSeed.toWizardAnswers — data spine sim contract', () {
    test('cadre_salarie_lpp_suisse_ready hydrates rich salaried LPP data', () {
      final seed = CoachProfileSeeds.registry['cadre_salarie_lpp_suisse_ready'];

      expect(seed, isNotNull,
          reason: 'The default runtime persona must be a rich salaried/LPP '
              'profile, not a thin swiss_native fallback.');

      final answers = seed!.toWizardAnswers(now: DateTime(2026));
      expect(answers['q_employment_status'], 'employed');
      expect(answers['q_canton'], 'VS');
      expect(answers['q_net_income_period_chf'], 7500.0);
      expect(answers['q_has_pension_fund'], isTrue);
      expect(answers['_coach_avoir_lpp'], 94000.0);
      expect(answers['_coach_avoir_lpp_oblig'], 76000.0);
      expect(answers['_coach_avoir_lpp_suroblig'], 18000.0);
      expect(answers['_coach_salaire_assure'], 86000.0);
      expect(answers['_coach_rachat_maximum'], 42000.0);
      expect(answers['_coach_lpp_source'], 'document_scan');
      expect(answers['q_3a_total'], 22000.0);
      expect(answers['q_housing_cost_period_chf'], 1850.0);
      expect(answers['q_lamal_premium_monthly_chf'], 430.0);
      expect(answers['q_cash_total'], 30000.0);

      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.firstName, 'Alex');
      expect(profile.age, 33);
      expect(profile.canton, 'VS');
      expect(profile.archetype, FinancialArchetype.swissNative);
      expect(profile.employmentStatus, 'salarie');
      expect(profile.explicitMonthlyNetIncome, 7500.0);
      expect(profile.prevoyance.avoirLppTotal, 94000.0);
      expect(profile.prevoyance.avoirLppObligatoire, 76000.0);
      expect(profile.prevoyance.avoirLppSurobligatoire, 18000.0);
      expect(profile.prevoyance.salaireAssure, 86000.0);
      expect(profile.prevoyance.rachatMaximum, 42000.0);
      expect(profile.prevoyance.totalEpargne3a, 22000.0);
      expect(
        profile.dataSources['prevoyance.avoirLppTotal'],
        ProfileDataSource.certificate,
      );

      final packet = CoachContextPacketAdapter.fromProfile(profile);
      final factIds = (packet['facts'] as List)
          .whereType<Map>()
          .map((fact) => fact['id'])
          .toSet();

      expect(factIds, contains('budget.monthly_capacity'));
      expect(factIds, contains('pillar.lpp.total_balance'));
      expect(factIds, contains('pillar.lpp.insured_salary'));
      expect(factIds, contains('pillar.lpp.buyback_max'));
      expect(factIds, contains('pillar.3a.total_balance'));
    });

    test('julien_swiss seed hydrates a packet-visible coach profile', () {
      final seed = CoachProfileSeeds.registry['julien_swiss']!;

      final profile = CoachProfile.fromWizardAnswers(seed.toWizardAnswers());
      final packet = CoachContextPacketAdapter.fromProfile(profile);
      final factIds = (packet['facts'] as List)
          .whereType<Map>()
          .map((fact) => fact['id'])
          .toSet();

      expect(profile.firstName, 'Julien');
      expect(profile.canton, 'VD');
      expect(profile.age, seed.age);
      expect(profile.archetype, FinancialArchetype.swissNative);
      expect(factIds, contains('budget.monthly_capacity'));
      expect(factIds, contains('pillar.lpp.total_balance'));
      expect(packet['next_questions'], isNotEmpty);
    });

    test('independent no-LPP seed hydrates income and 3a reality', () {
      final seed =
          CoachProfileSeeds.registry['independent_no_lpp_income_reality'];

      expect(seed, isNotNull,
          reason: 'CJT-061 has local report calculation proof; the next '
              'runtime persona-flow needs an explicit independent/no-LPP seed.');

      final answers = seed!.toWizardAnswers(now: DateTime(2026));
      expect(answers['q_employment_status'], 'independant');
      expect(
        answers['q_self_employed_net_income_annual_chf'],
        86400,
        reason: 'OPP3 art. 7 no-LPP calculations need annual professional '
            'net income, not the household monthly budget net.',
      );
      expect(answers['q_has_pension_fund'], isFalse);
      expect(answers['q_has_3a'], isTrue);
      expect(answers['q_3a_accounts_count'], 1);
      expect(answers['q_3a_annual_contribution'], greaterThan(0));
      expect(answers['q_savings_allocation'], contains('3a'));

      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.firstName, 'Nadia');
      expect(profile.archetype, FinancialArchetype.independentNoLpp);
      expect(profile.employmentStatus, 'independant');
      expect(profile.prevoyance.avoirLppTotal, 0);
      expect(profile.total3aMensuel, greaterThan(0));
      expect(profile.explicitMonthlyNetIncome, greaterThan(0));
      expect(profile.independentNetProfessionalIncomeAnnual, 86400);
    });
  });

  group('CoachProfileSeeds — cadre_3a_contributing (SALVAGE-00 SC-4)', () {
    // The device-layer twin of the SC-2 cross-path unit fixture. Pins the
    // load-bearing persona contract: a 3a-contributing seed must hydrate a
    // profile with total3aMensuel > 0 so the SC-4 device gate (Plan 04)
    // exercises a Futur>0 budget hero, not a flat persona.
    test('seed exists and is swiss_native', () {
      final seed = CoachProfileSeeds.registry['cadre_3a_contributing'];
      expect(seed, isNotNull,
          reason: 'cadre_3a_contributing is the SC-4 device persona referenced '
              'by flow_money_trust_chain_3a_contributing.yaml');
      expect(seed!.archetype, 'swiss_native');
    });

    test('hydrated profile yields total3aMensuel > 0 (Futur>0 budget hero)',
        () {
      final seed = CoachProfileSeeds.registry['cadre_3a_contributing']!;
      final profile = CoachProfile.fromWizardAnswers(seed.toWizardAnswers());
      expect(profile.total3aMensuel, greaterThan(0),
          reason: 'a 3a-contributing persona must produce planned 3a savings '
              'so the budget hero renders Futur > 0');
    });
  });

  group('CoachProfileSeeds — frontalier_geneve (Tier B Lot B5 cross_border)',
      () {
    test('by_archetype_cross_border_returns_frontalier_geneve_seed', () {
      // BLOCKING contract closed by this seed. The Tier B smoke build passes
      // --dart-define=MINT_E2E_ARCHETYPE=cross_border (archetype slug). Before
      // this seed, byArchetype('cross_border') was null → the seeded frontalier
      // build booted a navigable guest shell WITHOUT a profile → smoke C2
      // (non-empty + chiffré) failed. NEVER #7 forbids frontalier as edge case.
      final byArchetype = CoachProfileSeeds.byArchetype('cross_border');
      final directLookup = CoachProfileSeeds.registry['frontalier_geneve'];
      expect(byArchetype, isNotNull,
          reason: 'archetype slug cross_border MUST resolve via byArchetype so '
              'MINT_E2E_ARCHETYPE=cross_border hydrates a frontalier profile.');
      expect(byArchetype, same(directLookup),
          reason:
              'archetype slug cross_border MUST map to seed frontalier_geneve.');
    });

    test('seed_registry_contains_frontalier_geneve_cross_border', () {
      final seed = CoachProfileSeeds.registry['frontalier_geneve'];
      expect(seed, isNotNull);
      expect(seed!.archetype, 'cross_border');
      expect(seed.canton, 'GE',
          reason: 'emploi Genève — le frontalier travaille dans le canton.');
      expect(seed.nationality, 'FR',
          reason: 'résident France.');
      expect(seed.residencePermit, 'permit_g',
          reason: 'permis G est le signal frontalier (imposé à la source, '
              'barème A0 pour un célibataire sans charge).');
    });

    test('frontalier_geneve hydrates a crossBorder profile via permit G', () {
      final seed = CoachProfileSeeds.registry['frontalier_geneve']!;
      final answers = seed.toWizardAnswers(now: DateTime(2026));

      // The seed MUST emit the permit signal for the archetype getter.
      expect(answers['q_residence_permit'], 'permit_g');
      expect(answers['q_nationality'], 'FR');

      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.archetype, FinancialArchetype.crossBorder,
          reason: 'permit_g normalizes to G → FinancialArchetype.crossBorder '
              '(coach_profile.dart archetype getter).');
      expect(profile.isCrossBorder, isTrue);
      expect(profile.residencePermit, 'G',
          reason: 'normalizeResidencePermit(permit_g) == G.');
      expect(profile.firstName, 'Nicolas');
      expect(profile.age, 41);
      expect(profile.canton, 'GE');
    });

    test('frontalier_geneve is NOT quasi-resident → no deductible 3a', () {
      // Métier: cotiser au 3a reste possible pour un frontalier, mais sans le
      // statut de quasi-résident genevois (>90 % du revenu mondial de source
      // suisse) la cotisation n'ouvre AUCUNE déduction fiscale → une persona
      // rationnelle n'en ouvre pas. Le seed ne doit donc PAS fabriquer une
      // cotisation 3a synthétique via le fallback d'allocation d'épargne.
      final seed = CoachProfileSeeds.registry['frontalier_geneve']!;
      final answers = seed.toWizardAnswers(now: DateTime(2026));

      expect(answers['q_has_3a'], isFalse);
      expect(answers['q_3a_annual_contribution'], 0.0);
      expect(answers['q_3a_accounts_count'], 0);
      expect(answers['q_savings_allocation'], isNot(contains('3a')));

      final profile = CoachProfile.fromWizardAnswers(answers);
      expect(profile.total3aMensuel, 0);
    });

    test('frontalier_geneve boot produces a non-empty, chiffré /home', () {
      // Mechanism proof (NOT sim): the seeded profile must carry the numeric
      // facts /home renders — budget capacity + LPP balance — so the shell is
      // never "Aucune donnée" (smoke C2). Mirrors the julien_swiss /
      // cadre_salarie packet-visibility contracts above.
      final seed = CoachProfileSeeds.registry['frontalier_geneve']!;
      final profile = CoachProfile.fromWizardAnswers(seed.toWizardAnswers());

      // Chiffré: real income + LPP present (Swiss 2nd pillar for the frontalier).
      expect(profile.explicitMonthlyNetIncome, greaterThan(0));
      expect(profile.prevoyance.avoirLppTotal, 82000.0);
      expect(profile.prevoyance.salaireAssure, 55000.0);

      final packet = CoachContextPacketAdapter.fromProfile(profile);
      final factIds = (packet['facts'] as List)
          .whereType<Map>()
          .map((fact) => fact['id'])
          .toSet();

      expect(factIds, contains('budget.monthly_capacity'),
          reason: 'a non-empty budget hero must be computable from the seed.');
      expect(factIds, contains('pillar.lpp.total_balance'),
          reason: 'the frontalier cotise au 2e pilier suisse — LPP fact must '
              'be visible.');
    });
  });

  // ── Tier B smoke — persona FAMILLE (couple marié double-revenu, 1 enfant) ──
  // Verrouille le contrat de seed qui débloque le C2 « chiffré » des 4 écrans
  // famille : sans conjoint / genre / enfant côté profil, les gates P2 dur
  // restaient fermés (aucune seed existante ne porte de famille).
  group('CoachProfileSeeds — famille_bern (Tier B smoke famille)', () {
    test('seed_registry_contains_famille_bern', () {
      final seed = CoachProfileSeeds.registry['famille_bern'];
      expect(seed, isNotNull,
          reason: 'famille_bern doit exister pour exposer une persona famille '
              'via MINT_E2E_ARCHETYPE=famille_bern (seedKey direct).');
      expect(seed!.archetype, 'swiss_native',
          reason: 'un couple marié suisse reste swiss_native — la famille est '
              'une variante de ménage, pas un archétype financier.');
      expect(seed.canton, 'BE');
      expect(seed.gender, 'F');
      expect(seed.civilStatus, 'married');
      expect(seed.nombreEnfants, 1);
      expect(seed.partnerNetMonthlyIncome, isNotNull,
          reason: 'le revenu 2 (conjoint réel) est le fait qui débloque le '
              'partage mariage / concubinage.');
    });

    test('famille_bern is exposed as a direct seedKey (forcedArchetypeSlug)', () {
      // Le smoke build passe MINT_E2E_ARCHETYPE=famille_bern ; comme la clé
      // existe dans registry, forcedArchetypeSlug la résout directement (pas
      // besoin d'un arm byArchetype — la famille n'est pas un FinancialArchetype).
      expect(CoachProfileSeeds.bySlug('famille_bern'), isNotNull);
      expect(CoachProfileSeeds.registry.containsKey('famille_bern'), isTrue);
    });

    test('famille_bern emits the couple wizard answers (household + conjoint)',
        () {
      final seed = CoachProfileSeeds.registry['famille_bern']!;
      final answers = seed.toWizardAnswers(now: DateTime(2026));

      expect(answers['q_household_type'], 'couple',
          reason: 'un état civil marié / un conjoint ⇒ ménage couple, sinon le '
              'gate ghost-conjoint de fromWizardAnswers supprime le conjoint.');
      expect(answers['q_civil_status'], 'married');
      expect(answers['q_gender'], 'F');
      expect(answers['q_children'], 1);
      expect(answers['q_partner_net_income_chf'], 5556);
      expect(answers['q_gross_salary_annual'], 114000.0);
    });

    test('famille_bern hydrates a couple profile with ALL family gate facts',
        () {
      final seed = CoachProfileSeeds.registry['famille_bern']!;
      final profile = CoachProfile.fromWizardAnswers(seed.toWizardAnswers());

      // Revenu 1 (l'utilisateur) — clé 'salary' + brut mensuel dans les plages
      // des écrans famille [2000, 15000] mensuel / [30000, 200000] annuel.
      expect(profile.userProvidedFields, contains('salary'));
      expect(profile.salaireBrutMensuel, 9500.0,
          reason: '114 000 / 12 — dans la plage du congé (naissance) et de '
              'l\'impact fiscal.');

      // Revenu 2 (le conjoint réel) — matérialisé, salaire BRUT via le facteur
      // canonique IncomeConverter (~1.17 × net 5556 ≈ 6500), annuel < 300 000.
      expect(profile.conjoint, isNotNull,
          reason: 'le conjoint réel débloque revenu2 (mariage + concubinage).');
      final conjointGrossMonthly = profile.conjoint!.salaireBrutMensuel!;
      expect(conjointGrossMonthly, closeTo(6500, 30));
      expect(conjointGrossMonthly * profile.conjoint!.nombreDeMois,
          lessThanOrEqualTo(300000.0));

      // Canton — clé 'canton' réelle + code valide (barème famille).
      expect(profile.userProvidedFields, contains('canton'));
      expect(profile.canton, 'BE');

      // Genre — rôle parental de naissance (congé maternité).
      expect(profile.gender, 'F',
          reason: 'le rôle parental de naissance_screen gate sur gender.');

      // Enfant — pré-remplit les compteurs et confirme le fait côté divorce.
      expect(profile.nombreEnfants, 1);

      // LPP de l'utilisateur issue d'un certificat — le partage LPP du divorce
      // exige une valeur RÉELLE (jamais estimée), et la rente de survivant du
      // mariage dérive de cet avoir.
      expect(profile.userProvidedFields, contains('avoirLpp'));
      expect(profile.prevoyance.avoirLppTotal, 180000.0);
      expect(profile.prevoyance.isLppFromCertificate, isTrue,
          reason: 'salaire assuré déclaré ⇒ certificat ⇒ divorce lpp1 seedé.');
    });
  });
}
