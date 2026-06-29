function normalize(raw) {
  if (raw == null) {
    throw new Error('Money Trust: bootstrap capture was null/undefined');
  }
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

var bootstrap = normalize(output.money_trust_bootstrap);

for (var expected of [
  'slug=cadre_salarie_lpp_suisse_ready',
  'mode=establish',
  'seed=absent',
  'planned3a=7056',
]) {
  if (!bootstrap.includes(expected)) {
    throw new Error(
      'Money Trust: bootstrap missing ' + expected + ': "' + bootstrap + '"'
    );
  }
}

if (
  !bootstrap.includes('storage=secureSeal') &&
  !bootstrap.includes('storage=debugPlainFallback')
) {
  throw new Error(
    'Money Trust: bootstrap did not expose storage mode: "' + bootstrap + '"'
  );
}

if (bootstrap.includes('annual=')) {
  throw new Error(
    'Money Trust: salaried fixture was demoted to self-employed: "' +
      bootstrap +
      '"'
  );
}

output.money_trust_profile_bootstrap_assertion = 'PASS';
console.log(
  'MONEY_TRUST_PROFILE_BOOTSTRAP ' +
    JSON.stringify({
      verdict: output.money_trust_profile_bootstrap_assertion,
      bootstrap: bootstrap,
    })
);
