function normalize(raw) {
  if (raw == null) {
    throw new Error('Row23: bootstrap capture was null/undefined');
  }
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

var establish = normalize(output.row23_bootstrap_establish);
var update = normalize(output.row23_bootstrap_update);

for (var expected of ['seed=absent', 'annual=86400', 'planned3a=6000']) {
  if (!establish.includes(expected)) {
    throw new Error('Row23: establish bootstrap missing ' + expected + ': "' + establish + '"');
  }
}
if (!establish.includes('storage=secureSeal') && !establish.includes('storage=debugPlainFallback')) {
  throw new Error('Row23: establish bootstrap did not expose storage mode: "' + establish + '"');
}

for (var expected of ['mode=updateIncome', 'seed=absent', 'annual=96000', 'planned3a=6000']) {
  if (!update.includes(expected)) {
    throw new Error('Row23: update bootstrap missing ' + expected + ': "' + update + '"');
  }
}
if (!update.includes('storage=secureSeal') && !update.includes('storage=debugPlainFallback')) {
  throw new Error('Row23: update bootstrap did not expose storage mode: "' + update + '"');
}

output.row23_profile_bootstrap_assertion = 'PASS';
console.log(
  'ROW23_PROFILE_BOOTSTRAP ' +
    JSON.stringify({
      verdict: output.row23_profile_bootstrap_assertion,
      establish: establish,
      update: update,
    })
);
