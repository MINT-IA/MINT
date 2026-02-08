# Insert: q_has_consumer_credit (Konsumkredit)

## Metadata
```yaml
questionId: "q_has_consumer_credit"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Antwort "Ja" bei der Frage `q_has_consumer_credit`.
- Betrag > 0.

## Inputs
- Geliehener Betrag
- Effektivzins (Gesamteffektivzins)
- Restlaufzeit

## Outputs
- Gesamtkosten der verbleibenden Zinsen.
- Vergleich mit einer Sparanlage.

## Hypothèses
- Gesamteffektivzins pro Jahr vom Benutzer angegeben.
- Konstante monatliche Rückzahlung (Vereinfachung).
- Keine Vorfälligkeitsentschädigung (Standard KKG).

## Limites
- Berücksichtigt keine eventuellen Bearbeitungsgebühren oder Restkreditversicherungen.
- Die Berechnung ist eine lineare Schätzung.

## Disclaimer
"Vereinfachte Berechnung basierend auf linearer Rückzahlung. Die tatsächlichen Kosten können je nach den Bedingungen deines Vertrags variieren. Dies ist keine offizielle Berechnung."

## Action
"Wenn dieser Kredit dich teuer zu stehen kommt, kann es sinnvoll sein, ihn in deinem Plan zu priorisieren — je nach deiner Situation und deinen anderen Verpflichtungen."

## Reminder
"In 6 Monaten: Restbetrag überprüfen."

## Safe Mode
Falls dieser Kredit erkannt wird → Safe Mode aktivieren und Rückzahlung vor jeglichem Sparen priorisieren.
