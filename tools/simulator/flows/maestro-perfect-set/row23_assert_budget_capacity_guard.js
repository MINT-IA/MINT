// Row 23 independent/no-LPP runtime proof.
//
// Assert the /budget capacity guard separates legal 3a room from monthly
// payment capacity and keeps product/salary-only surfaces out of the flow.

function normalize(raw) {
  if (raw == null) {
    throw new Error('Row23: budget capacity guard capture was null/undefined');
  }
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

var guard = normalize(output.row23_budget_capacity_guard);

[
  'Clarifier mon statut indépendant avant d’augmenter le 3a',
  'statut AVS',
  'revenu imposable',
  'volatilité de tes revenus',
  'couvertures risque',
  'LPP facultative',
  'liquidité',
].forEach(function (needle) {
  if (!guard.includes(normalize(needle))) {
    throw new Error(
      'Row23: expected Budget capacity guard fragment "' +
        needle +
        '", got: "' +
        guard +
        '"'
    );
  }
});

[
  'Plafond 3a salarié',
  '7’258',
  'ouvrir un',
  'ouvrir ton',
  'Ouvre',
  'fintech',
  'UBS',
  'Raiffeisen',
  'Swiss Life',
  '60% actions',
].forEach(function (bad) {
  if (guard.includes(normalize(bad))) {
    throw new Error(
      'Row23: Budget capacity guard exposed forbidden fragment "' +
        bad +
        '": "' +
        guard +
        '"'
    );
  }
});

output.row23_budget_capacity_guard_assertion = 'PASS';
console.log(
  'ROW23_BUDGET_CAPACITY_GUARD ' +
    JSON.stringify({
      verdict: output.row23_budget_capacity_guard_assertion,
      guard: guard,
    })
);
