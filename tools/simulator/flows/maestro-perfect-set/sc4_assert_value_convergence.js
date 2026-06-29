// sc4_assert_value_convergence.js — SC-4 value-convergence assertion.
//
// The heart of SALVAGE-00 SC-4: prove the SAME "Disponible/mois"
// (argent libre / present.monthlyFree) value renders IDENTICALLY across the
// three money surfaces — Mon Argent, /budget, and the coach chat-open surface
// — for the active persisted runtime persona.
//
// Each surface formats the figure differently in layout/wording, so we extract
// the relevant CHF numeric token (Swiss apostrophe thousands sep, e.g. 3'152):
//   - /budget    captured node "budget_hero_formula":
//                "Disponible ce mois: CHF 3'152. CHF 7'020 − CHF 3'280 − CHF 588 = CHF 3'152"
//                => take the token AFTER the final "=" (the monthlyFree result).
//   - Mon Argent captured node "mon_argent_budget_summary":
//                "Ton budget ce mois. Revenus 7'020 CHF. Dépenses 3'868 CHF. Reste 3'152 CHF."
//                => take the token immediately before "CHF" that follows "Reste".
//   - Coach      captured node text "Capacité mensuelle: CHF 3'740"
//                => take the token after "CHF".
//
// If the trust-chain (#681/#682) converges the builder path onto the engine
// path, all three tokens are byte-identical. Any divergence => throw => the
// flow FAILS. (Per the SC-4 device probe, the coach surface renders
// budget.monthly_capacity, NOT monthly_free, so this assertion surfaces that
// divergence truthfully rather than masking it.)

function norm(raw) {
  if (raw == null) {
    throw new Error('SC-4 capture was null/undefined — copyTextFrom matched no element');
  }
  // Strip NBSP ( ) so " CHF" matches uniformly; normalise the two
  // apostrophe glyphs the app uses (' U+0027 and ’ U+2019) to a single one.
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

function tokenAfterEquals(s) {
  // "... = CHF 3'152"
  var m = s.match(/=\s*CHF\s*(-?\d[\d']*)/);
  return m ? m[1] : null;
}

function tokenAfterReste(s) {
  // "... Reste 3'152 CHF."
  var m = s.match(/Reste\s*(-?\d[\d']*)\s*CHF/i);
  return m ? m[1] : null;
}

function tokenAfterCHF(s) {
  // "Capacité mensuelle: CHF 3'740"
  var m = s.match(/CHF\s*(-?\d[\d']*)/);
  if (m) return m[1];
  // fallback: "<n> CHF"
  m = s.match(/(-?\d[\d']*)\s*CHF/);
  return m ? m[1] : null;
}

function firstNumber(s) {
  var m = s.match(/-?\d[\d']*/);
  return m ? m[0] : null;
}

var budgetRaw = norm(output.sc4_budget);
var monArgentRaw = norm(output.sc4_mon_argent);
var coachRaw = norm(output.sc4_coach);

var budget = tokenAfterEquals(budgetRaw) || tokenAfterCHF(budgetRaw) || firstNumber(budgetRaw);
var monArgent = tokenAfterReste(monArgentRaw) || tokenAfterCHF(monArgentRaw) || firstNumber(monArgentRaw);
var coach = tokenAfterCHF(coachRaw) || firstNumber(coachRaw);

if (budget == null)    throw new Error('SC-4: no monthlyFree token in /budget capture: "' + budgetRaw + '"');
if (monArgent == null) throw new Error('SC-4: no monthlyFree token in Mon Argent capture: "' + monArgentRaw + '"');
if (coach == null)     throw new Error('SC-4: no CHF token in coach capture: "' + coachRaw + '"');

output.sc4_budget_token = budget;
output.sc4_mon_argent_token = monArgent;
output.sc4_coach_token = coach;

var allEqual = (budget === monArgent) && (monArgent === coach);
output.sc4_converged = allEqual ? 'PASS' : 'FAIL';

var summary =
  'SC-4 value convergence: ' +
  'budget="' + budget + '" ' +
  'mon_argent="' + monArgent + '" ' +
  'coach="' + coach + '" => ' + output.sc4_converged;
output.sc4_summary = summary;

// Surface the captured tokens + raw strings deterministically into the log so
// the rerun evidence shows the exact CHF value seen on each surface, not just
// a pass/fail bit. (json output below makes the values greppable from disk.)
output.sc4_evidence_json = JSON.stringify({
  budget_token: budget, mon_argent_token: monArgent, coach_token: coach,
  verdict: output.sc4_converged,
  budget_raw: budgetRaw, mon_argent_raw: monArgentRaw, coach_raw: coachRaw,
});
console.log('SC4_EVIDENCE ' + output.sc4_evidence_json);
console.log(summary);

if (!allEqual) {
  throw new Error(
    'SC-4 FAIL — Disponible/mois (monthlyFree) DIVERGES across surfaces. ' + summary +
    ' (raw: budget="' + budgetRaw + '", mon_argent="' + monArgentRaw +
    '", coach="' + coachRaw + '")'
  );
}
