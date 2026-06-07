function normalize(raw) {
  if (raw == null) {
    throw new Error('Row23: budget capture was null/undefined');
  }
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

var basis = normalize(output.row23_budget_basis);
var formula = normalize(output.row23_budget_formula);

if (!basis.includes('source=derived_self_employed_annual_proxy')) {
  throw new Error('Row23: budget basis did not use independent annual proxy: "' + basis + '"');
}
if (!basis.includes('q_self_employed_net_income_annual_chf=96000')) {
  throw new Error('Row23: budget basis did not expose updated annual 96000: "' + basis + '"');
}
if (!basis.includes("monthly_net=CHF 8'000")) {
  throw new Error('Row23: budget basis did not expose updated monthly CHF 8\'000: "' + basis + '"');
}
if (!formula.includes("CHF 8'000")) {
  throw new Error('Row23: budget formula did not use updated CHF 8\'000 income: "' + formula + '"');
}
if (basis.includes('86400') || basis.includes("CHF 7'200") || formula.includes("CHF 7'200")) {
  throw new Error('Row23: budget still exposes stale 86\'400 / CHF 7\'200 values: basis="' + basis + '" formula="' + formula + '"');
}

output.row23_budget_updated_income_assertion = 'PASS';
console.log(
  'ROW23_UPDATED_INCOME_BUDGET ' +
    JSON.stringify({
      verdict: output.row23_budget_updated_income_assertion,
      basis: basis,
      formula: formula,
    })
);
