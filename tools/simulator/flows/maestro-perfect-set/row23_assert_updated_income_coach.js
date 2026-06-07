function normalize(raw) {
  if (raw == null) {
    throw new Error('Row23: coach answer capture was null/undefined');
  }
  return String(raw).replace(/ /g, ' ').replace(/’/g, "'");
}

var answer = normalize(output.row23_coach_answer);

for (var expected of ["96 000 CHF/an", "13 200 CHF/an", 'Marge 3a à vérifier']) {
  if (!answer.includes(expected)) {
    throw new Error('Row23: coach answer missing ' + expected + ': "' + answer + '"');
  }
}

for (var forbidden of [
  "86'400 CHF/an",
  "86 400 CHF/an",
  "11'280 CHF/an",
  "11 280 CHF/an",
  'Donnée manquante côté MINT',
  'Impact fiscal indicatif',
]) {
  if (answer.includes(forbidden)) {
    throw new Error('Row23: coach answer exposes stale/misleading text ' + forbidden + ': "' + answer + '"');
  }
}

output.row23_coach_updated_income_assertion = 'PASS';
console.log(
  'ROW23_UPDATED_INCOME_COACH ' +
    JSON.stringify({
      verdict: output.row23_coach_updated_income_assertion,
      answer: answer,
    })
);
