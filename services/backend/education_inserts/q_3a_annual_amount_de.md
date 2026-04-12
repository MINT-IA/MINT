# Insert: q_3a_annual_amount (Steuerersparnis Säule 3a)

## Metadata
```yaml
questionId: "q_3a_annual_amount"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Antwort > 0 bei der Frage `q_3a_annual_amount`.

## Inputs
- Einbezahlter Betrag Säule 3a
- Steuerbares Einkommen
- Wohnsitzkanton

## Outputs
- Geschätzte Steuerersparnis (CHF)
- Netto-Sparaufwand (Einbezahlt - Ersparnis)

## Hypothèses
- Geschätzter Grenzsteuersatz (kantonale Durchschnittsspanne).
- Status ledig als Standard (falls nicht präzisiert).

## Limites
- Berücksichtigt keine weiteren möglichen Abzüge.
- Die Steuersätze können sich jährlich ändern.

## Disclaimer
"Indikative Schätzung basierend auf Annahmen. Dies ist keine offizielle Berechnung."

## Action
"Wachstum simulieren"

## Reminder
"November: Erinnerung zur Optimierung der Einzahlung vor Jahresende."

## Safe Mode
Deaktiviert, falls Schulden erkannt werden (Priorität auf Rückzahlung).
