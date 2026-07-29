/// Home (Aujourd'hui) glue between [CoachProfile] and the life-event
/// suggestion cards, PR-D of the firstJob vertical tranche
/// (TRANCHE-FIRSTJOB-SPEC §1 T3 / §3.1).
///
/// The eligibility rules live in [buildLifeEventSuggestions]; this file only
/// translates the CoachProfile representation (French labels + enums) into the
/// primitive contract that builder expects, and owns the home-specific
/// accessibility identifiers. Kept out of the screen widget so it is
/// unit-testable without a BuildContext — it doubles as the deterministic
/// seed-fixture proof that a 25-year-old profile surfaces the firstJob card.
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';

/// Builds the ordered life-event suggestions for /home from [profile].
///
/// The firstJob card gates on `age <= 28` (see [buildLifeEventSuggestions]),
/// so a 25-year-old salaried profile always yields a `/first-job` entry.
List<LifeEventSuggestion> homeLifeEventSuggestions(CoachProfile profile, S s) {
  final age = profile.ageOrNull;
  // Without a known age we cannot responsibly gate age-driven life events
  // (firstJob <= 28, succession >= 50, retraite >= 55). Surface nothing
  // rather than a wrong card — the caller then renders no section (D4).
  if (age == null) return const [];
  return buildLifeEventSuggestions(
    age: age,
    civilStatus: _civilStatus(profile.etatCivil),
    childrenCount: profile.nombreEnfants,
    employmentStatus: _employmentStatus(profile.employmentStatus),
    // Internal gating input only (never rendered): prefer the declared net,
    // fall back to gross when net is unknown so income-gated suggestions are
    // not silently suppressed. Not a displayed financial figure.
    monthlyNetIncome:
        profile.explicitMonthlyNetIncome ?? profile.salaireBrutMensuel,
    canton: profile.canton,
    s: s,
  );
}

/// Stable Maestro / a11y identifier for a home life-event card.
///
/// Only the firstJob entry is under acceptance contract today
/// (`home-lifeevent-card-firstJob`, TRANCHE-FIRSTJOB-SPEC §3.1). Other routes
/// return `null` until their own tranche wires an acceptance flow, so the
/// generic section never carries a home-specific id on other surfaces.
String? homeLifeEventCardIdentifier(LifeEventSuggestion suggestion) {
  return suggestion.route == '/first-job'
      ? 'home-lifeevent-card-firstJob'
      : null;
}

/// Maps [CoachCivilStatus] to the primitive string the suggestion builder
/// checks (`'single'` / `'married'` / `'concubinage'`).
String _civilStatus(CoachCivilStatus status) {
  switch (status) {
    case CoachCivilStatus.marie:
      return 'married';
    case CoachCivilStatus.concubinage:
      return 'concubinage';
    case CoachCivilStatus.celibataire:
    case CoachCivilStatus.divorce:
    case CoachCivilStatus.veuf:
      return 'single';
  }
}

/// Maps CoachProfile's French employment status to the primitive string the
/// suggestion builder checks (`'employee'` / `'independent'`).
String _employmentStatus(String raw) {
  switch (raw) {
    case 'salarie':
      return 'employee';
    case 'independant':
      return 'independent';
    default:
      return raw;
  }
}
