// Scenario Narrator Service — Sprint S37.
//
// Narrates 3 retirement scenarios (prudent/base/optimiste) as
// educational text anchored on concrete numbers.
//
// Without BYOK: deterministic structured text.
// With BYOK (future): LLM generates -> ComplianceGuard validates.
//
// Each narrative: max 150 words.
// Each MUST mention return assumption and uncertainty.
// No prescriptive language, no banned terms.
// All French, informal "tu".

// ────────────────────────────────────────────────────────────
//  DATA CLASSES
// ────────────────────────────────────────────────────────────

/// A single narrated scenario with its key figures and text.
class NarratedScenario {
  final String label;

  /// Educational narrative text (max 150 words).
  final String narrative;
  final double annualReturnPct;
  final double capitalFinal;
  final double monthlyIncome;

  const NarratedScenario({
    required this.label,
    required this.narrative,
    required this.annualReturnPct,
    required this.capitalFinal,
    required this.monthlyIncome,
  });
}

/// Result containing 3 narrated scenarios + compliance fields.
class ScenarioNarrationResult {
  final List<NarratedScenario> scenarios;
  final String disclaimer;
  final List<String> sources;

  const ScenarioNarrationResult({
    required this.scenarios,
    required this.disclaimer,
    required this.sources,
  });
}

// ────────────────────────────────────────────────────────────
//  SERVICE
// ────────────────────────────────────────────────────────────

/// Deterministic scenario narrator.
///
/// Takes ForecasterService output figures and produces
/// educational narrative text for each of the 3 scenarios.
class ScenarioNarratorService {
  ScenarioNarratorService._();

  /// Narrate 3 scenarios from ForecasterService output.
  ///
  /// [prudentCapital] / [prudentMonthly] — prudent scenario figures.
  /// [baseCapital] / [baseMonthly] — base scenario figures.
  /// [optimisteCapital] / [optimisteMonthly] — optimiste scenario figures.
  /// [firstName] — user first name for personalisation.
  static ScenarioNarrationResult narrate({
    required double prudentCapital,
    required double prudentMonthly,
    required double baseCapital,
    required double baseMonthly,
    required double optimisteCapital,
    required double optimisteMonthly,
    String firstName = 'utilisateur',
  }) {
    final scenarios = <NarratedScenario>[
      NarratedScenario(
        label: 'Scenario prudent',
        annualReturnPct: 1.0,
        capitalFinal: prudentCapital,
        monthlyIncome: prudentMonthly,
        narrative: _narratePrudent(
          capital: prudentCapital,
          monthly: prudentMonthly,
          firstName: firstName,
        ),
      ),
      NarratedScenario(
        label: 'Scenario de reference',
        annualReturnPct: 4.5,
        capitalFinal: baseCapital,
        monthlyIncome: baseMonthly,
        narrative: _narrateBase(
          capital: baseCapital,
          monthly: baseMonthly,
          firstName: firstName,
        ),
      ),
      NarratedScenario(
        label: 'Scenario favorable',
        annualReturnPct: 7.0,
        capitalFinal: optimisteCapital,
        monthlyIncome: optimisteMonthly,
        narrative: _narrateOptimiste(
          capital: optimisteCapital,
          monthly: optimisteMonthly,
          firstName: firstName,
        ),
      ),
    ];

    return ScenarioNarrationResult(
      scenarios: scenarios,
      disclaimer:
          'Outil éducatif — ne constitue pas un conseil financier au sens '
          'de la LSFin. Les projections reposent sur des hypothèses de '
          'rendement et ne présagent pas des résultats futurs. '
          'Consulte un·e spécialiste pour un plan personnalisé.',
      sources: [
        'LAVS art. 21-29 (rente AVS)',
        'LPP art. 14 (taux de conversion)',
        'OPP3 art. 7 (plafond 3a)',
        'LPP art. 15-16 (bonifications)',
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  NARRATIVE TEMPLATES
  // ════════════════════════════════════════════════════════════════

  static String _narratePrudent({
    required double capital,
    required double monthly,
    required String firstName,
  }) {
    final chfCapital = _formatChf(capital);
    final chfMonthly = _formatChf(monthly);
    return 'Scenario prudent (rendement ~1%/an) : '
        '$firstName, avec un capital estime a CHF $chfCapital a la retraite, '
        'ta rente mensuelle pourrait avoisiner CHF $chfMonthly. '
        'Ce scenario suppose une croissance modeste de tes avoirs, '
        'proche des taux obligatoires LPP actuels. '
        "L'incertitude reste presente — les marches peuvent evoluer "
        'differemment et les conditions economiques changer au fil des annees.';
  }

  static String _narrateBase({
    required double capital,
    required double monthly,
    required String firstName,
  }) {
    final chfCapital = _formatChf(capital);
    final chfMonthly = _formatChf(monthly);
    return 'Scenario de reference (rendement ~4.5%/an) : '
        '$firstName, le capital estime atteindrait CHF $chfCapital, '
        'soit environ CHF $chfMonthly/mois de revenu a la retraite. '
        'Ce scenario repose sur des hypotheses medianes historiques. '
        'Les resultats reels dependront de nombreux facteurs : '
        'inflation, performances des marches, evolution de ta carriere '
        'et de tes versements.';
  }

  static String _narrateOptimiste({
    required double capital,
    required double monthly,
    required String firstName,
  }) {
    final chfCapital = _formatChf(capital);
    final chfMonthly = _formatChf(monthly);
    return 'Scenario favorable (rendement ~7%/an) : '
        '$firstName, CHF $chfCapital en capital, '
        'soit environ CHF $chfMonthly/mois. '
        'Ce scenario suppose des conditions de marche favorables '
        'sur une longue periode. Les projections restent des estimations '
        '— aucun rendement futur ne peut etre predit avec exactitude. '
        'Diversification et discipline restent des leviers importants.';
  }

  // ════════════════════════════════════════════════════════════════
  //  FORMATTING HELPERS
  // ════════════════════════════════════════════════════════════════

  /// Format a number with Swiss apostrophe grouping (e.g. 1'250'000).
  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    if (intVal < 0) buffer.write('-');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
