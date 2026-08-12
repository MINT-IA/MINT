import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/mint_next_marge_3a_calculator.dart';

void main() {
  MintNextMarge3aResult compute({
    int taxYear = 2026,
    String branch = 'lpp_affiliated_max',
    int? annualNetCents,
    String? revenuRevision,
    int? totalVerseCents = 550000,
    String? versementsBucketRevision = 'rev-v#3',
    String? lppRevision = 'rev-lpp#1',
    Map<int, MintNextMarge3aRegulatorySet>? registryOverride,
    Set<String>? allowlistOverride,
  }) =>
      MintNextMarge3aCalculator.compute(
        taxYear: taxYear,
        plafondDetermination: branch,
        annualNetCents: annualNetCents,
        revenuRevision: revenuRevision,
        totalVerseCents: totalVerseCents,
        versementsBucketRevision: versementsBucketRevision,
        lppRevision: lppRevision,
        registryOverride: registryOverride,
        allowlistOverride: allowlistOverride,
      );

  test('the 2026 regulatory set is complete, hashed and allowlisted', () {
    const set = MintNextMarge3aRegistry.set2026;
    expect(set.isComplete, isTrue);
    expect(set.plafondLppAffiliatedCents, 725800,
        reason: 'petit 3a 7\'258 CHF — OPP3 art. 7, valeurs canoniques MINT');
    expect(set.grandPlafondCents, 3628800);
    expect(
      MintNextMarge3aRegistry.allowedSnapshotHashes,
      contains(set.snapshotHash),
      reason: 'toute dérive de valeur change le hash et sort de l\'allowlist',
    );
  });

  test('an incomplete set or unknown hash yields regulatory_constants_unattested',
      () {
    const tampered = MintNextMarge3aRegulatorySet(
      taxYear: 2026,
      plafondLppAffiliatedCents: 999999,
      grandPlafondCents: 3628800,
      nonAffiliatedRatePercent: 20,
      source: 'source falsifiée',
      effectivePeriod: '2025-01-01..2026-12-31',
      reviewedAt: '2026-03-26',
    );
    final tamperedResult = compute(registryOverride: {2026: tampered});
    expect(tamperedResult.status,
        MintNextMarge3aStatus.regulatoryConstantsUnattested);
    expect(tamperedResult.margeCents, isNull);

    final unknownHash = compute(allowlistOverride: {'0000'});
    expect(
        unknownHash.status, MintNextMarge3aStatus.regulatoryConstantsUnattested);
  });

  test('a year outside the registry yields unsupported_tax_year, never a '
      'fallback value', () {
    final r = compute(taxYear: 2025);
    expect(r.status, MintNextMarge3aStatus.unsupportedTaxYear);
    expect(r.plafondCents, isNull,
        reason: 'aucune reprise silencieuse d\'une valeur « courante »');
    expect(r.margeCents, isNull);
  });

  test('lpp affiliated branch uses the fixed attested plafond', () {
    final r = compute(totalVerseCents: 550000);
    expect(r.status, MintNextMarge3aStatus.available);
    expect(r.plafondCents, 725800);
    expect(r.margeCents, 725800 - 550000);
    expect(r.constantsVersionHash,
        MintNextMarge3aRegistry.set2026.snapshotHash);
    expect(r.parameterKeys, ['plafond_lpp_affiliated_cents']);
  });

  test('non affiliated branch is floor(20 percent of canonical annualized '
      'income) capped at the grand plafond', () {
    final under = compute(
      branch: 'non_affiliated_20pct_capped',
      annualNetCents: 7654321, // 20 % = 1530864.2 → floor 1530864
      revenuRevision: 'rev-r#1',
    );
    expect(under.status, MintNextMarge3aStatus.available);
    expect(under.plafondCents, 1530864,
        reason: 'floor au centime inférieur — jamais surestimer un plafond');

    final capped = compute(
      branch: 'non_affiliated_20pct_capped',
      annualNetCents: 25000000, // 20 % = 5'000'000 > grand plafond
      revenuRevision: 'rev-r#1',
    );
    expect(capped.plafondCents, 3628800);
    expect(capped.parameterKeys,
        ['non_affiliated_rate_percent', 'grand_plafond_cents']);
  });

  test('marge is signed: an overshoot stays negative, never clamped to zero',
      () {
    final r = compute(totalVerseCents: 1100000); // 11'000 versés > 7'258
    expect(r.status, MintNextMarge3aStatus.available);
    expect(r.margeCents, 725800 - 1100000);
    expect(r.margeCents, isNegative,
        reason: 'un dépassement est un fait utile — jamais masqué par 0');
  });

  test('same inputs yield bit identical results in cents', () {
    final a = compute(
        branch: 'non_affiliated_20pct_capped',
        annualNetCents: 7654321,
        revenuRevision: 'rev-r#1');
    final b = compute(
        branch: 'non_affiliated_20pct_capped',
        annualNetCents: 7654321,
        revenuRevision: 'rev-r#1');
    expect(a.plafondCents, b.plafondCents);
    expect(a.margeCents, b.margeCents);
    expect(a.constantsVersionHash, b.constantsVersionHash);
    expect(a.inputRevisions, b.inputRevisions);
  });

  test('unknown lpp affiliation yields lpp_affiliation_unknown', () {
    final r = compute(branch: 'undetermined_lpp_affiliation_unknown');
    expect(r.status, MintNextMarge3aStatus.lppAffiliationUnknown);
    expect(r.margeCents, isNull);
  });

  test('missing income blocks only the non affiliated branch', () {
    final blocked = compute(branch: 'undetermined_revenu_missing');
    expect(blocked.status, MintNextMarge3aStatus.incomeMissing);

    final alsoBlocked = compute(
        branch: 'non_affiliated_20pct_capped',
        annualNetCents: null,
        revenuRevision: 'rev-r#1');
    expect(alsoBlocked.status, MintNextMarge3aStatus.incomeMissing);

    final affiliatedWithoutIncome =
        compute(branch: 'lpp_affiliated_max', annualNetCents: null);
    expect(affiliatedWithoutIncome.status, MintNextMarge3aStatus.available,
        reason: 'le plafond fixe LPP n\'exige aucun revenu');
  });

  test('missing contributions yield contributions_missing', () {
    final r = compute(totalVerseCents: null, versementsBucketRevision: null);
    expect(r.status, MintNextMarge3aStatus.contributionsMissing);
    expect(r.margeCents, isNull,
        reason: 'pas de « plafond − 0 » fictif sans fait versements');
  });

  test('each of the six states is distinct and named, never a default number',
      () {
    final states = {
      compute(taxYear: 2031).status,
      compute(allowlistOverride: {'x'}).status,
      compute(branch: 'undetermined_lpp_affiliation_unknown').status,
      compute(branch: 'undetermined_revenu_missing').status,
      compute(totalVerseCents: null, versementsBucketRevision: null).status,
      MintNextMarge3aCalculator.revalidate(
          compute(), {'versements_bucket': 'other', 'lpp_affiliation': 'x'})
          .status,
    };
    expect(states, hasLength(6),
        reason: 'six états fail-closed distincts — aucun ne se confond');
    expect(states.contains(MintNextMarge3aStatus.available), isFalse);
    expect(() => compute(branch: 'garbage_branch'), throwsArgumentError,
        reason: 'une branche inconnue est un invariant violé, pas un état');
    expect(() => compute(branch: 'garbage_branch', taxYear: 2031),
        throwsArgumentError,
        reason: 'la validation de branche précède TOUT état métier — '
            'jamais convertie en unsupported_tax_year');
    expect(
        () => compute(branch: 'garbage_branch', allowlistOverride: {'x'}),
        throwsArgumentError,
        reason: 'jamais convertie en regulatory_constants_unattested');
  });

  test('sealing requires every consumed fact revision — an omitted revision '
      'is an invariant violation, never a silent hole', () {
    expect(() => compute(lppRevision: null), throwsArgumentError,
        reason: 'branche déterminée = fait LPP existant = révision exigée');
    expect(
        () => compute(
            branch: 'non_affiliated_20pct_capped',
            annualNetCents: 7654321,
            revenuRevision: null),
        throwsArgumentError,
        reason: 'la branche non-LPP consomme le revenu — révision exigée');
    final sealed = compute(
        branch: 'non_affiliated_20pct_capped',
        annualNetCents: 7654321,
        revenuRevision: 'rev-r#1');
    expect(sealed.inputRevisions.keys.toSet(),
        {'versements_bucket', 'lpp_affiliation', 'revenu'},
        reason: 'toutes les révisions consommées sont scellées');
    expect(
        MintNextMarge3aCalculator.revalidate(sealed, {
          'versements_bucket': 'rev-v#3',
          'lpp_affiliation': 'rev-lpp#1',
          'revenu': 'rev-r#2',
        }).status,
        MintNextMarge3aStatus.staleInputs,
        reason: 'un revenu corrigé périme la marge non-LPP');
  });

  test('impossible numeric domains are invariant violations, never plafonds',
      () {
    expect(
        () => compute(
            branch: 'non_affiliated_20pct_capped',
            annualNetCents: -7654321,
            revenuRevision: 'rev-r#1'),
        throwsArgumentError,
        reason: 'un revenu canonique est strictement positif — la troncature '
            'vers zéro de ~/ ne doit jamais fabriquer un plafond');
    expect(() => compute(totalVerseCents: -1), throwsArgumentError);
  });

  test('the result carries the input revisions and any strict inequality is '
      'stale', () {
    final r = compute();
    expect(r.inputRevisions,
        {'versements_bucket': 'rev-v#3', 'lpp_affiliation': 'rev-lpp#1'});

    final same = MintNextMarge3aCalculator.revalidate(
        r, {'versements_bucket': 'rev-v#3', 'lpp_affiliation': 'rev-lpp#1'});
    expect(same.status, MintNextMarge3aStatus.available);

    final bumped = MintNextMarge3aCalculator.revalidate(
        r, {'versements_bucket': 'rev-v#4', 'lpp_affiliation': 'rev-lpp#1'});
    expect(bumped.status, MintNextMarge3aStatus.staleInputs);

    final missingKey =
        MintNextMarge3aCalculator.revalidate(r, {'lpp_affiliation': 'rev-lpp#1'});
    expect(missingKey.status, MintNextMarge3aStatus.staleInputs,
        reason: 'clé disparue = inégalité stricte = stale');
  });

  test('a corrected versement re-derives the displayed marge', () {
    final before = compute(
        totalVerseCents: 550000, versementsBucketRevision: 'rev-v#3');
    final after = compute(
        totalVerseCents: 600000, versementsBucketRevision: 'rev-v#4');
    expect(before.margeCents, 725800 - 550000);
    expect(after.margeCents, 725800 - 600000);
    expect(
      MintNextMarge3aCalculator.revalidate(
              before, {'versements_bucket': 'rev-v#4', 'lpp_affiliation': 'rev-lpp#1'})
          .status,
      MintNextMarge3aStatus.staleInputs,
      reason: 'une marge périmée ne survit jamais à la correction d\'un fait',
    );
  });
}
