function normalize(raw) {
  if (raw == null) {
    throw new Error('Row23: report basis capture was null/undefined');
  }
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

var basis = normalize(output.row23_report_basis);

for (var expected of [
  'annual=96000',
  'hasLpp=false',
  'max3a=19200',
  'planned3a=6000',
  'remaining=13200',
]) {
  if (!basis.includes(expected)) {
    throw new Error('Row23: report basis missing ' + expected + ': "' + basis + '"');
  }
}

for (var forbidden of ['annual=86400', 'remaining=11280', 'max3a=7258', 'max3a=7056']) {
  if (basis.includes(forbidden)) {
    throw new Error('Row23: report basis exposes stale/salaried value ' + forbidden + ': "' + basis + '"');
  }
}

output.row23_report_updated_income_assertion = 'PASS';
console.log(
  'ROW23_UPDATED_INCOME_REPORT ' +
    JSON.stringify({
      verdict: output.row23_report_updated_income_assertion,
      basis: basis,
    })
);
