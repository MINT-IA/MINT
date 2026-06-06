// Row 23 independent/no-LPP runtime proof.
//
// Assert the /budget hero formula uses the canonical E2E fixture values without
// turning dynamic CHF strings into static Maestro locators.

function normalize(raw) {
  if (raw == null) {
    throw new Error('Row23: budget formula capture was null/undefined');
  }
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

var formula = normalize(output.row23_budget_formula);

if (!formula.includes("CHF 7'200")) {
  throw new Error(
    'Row23: expected independent fixture net income CHF 7\'200 in budget formula, got: "' +
      formula +
      '"'
  );
}

if (!formula.includes("CHF 3'333")) {
  throw new Error(
    'Row23: expected independent fixture monthly free CHF 3\'333 in budget formula, got: "' +
      formula +
      '"'
  );
}

output.row23_budget_formula_assertion = 'PASS';
console.log(
  'ROW23_INDEPENDENT_BUDGET_FORMULA ' +
    JSON.stringify({
      verdict: output.row23_budget_formula_assertion,
      formula: formula,
    })
);
