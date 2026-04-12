# Insert: q_has_pension_fund (BVG-Anschluss?)

## Metadata
```yaml
questionId: "q_has_pension_fund"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Antwort "Nein" oder "Unsicher" bei `q_has_pension_fund`.

## Inputs
- Status (Angestellt / Selbstständig)
- Jahreseinkommen

## Outputs
- Wahrscheinlicher Status (Obligatorisch angeschlossen oder nicht).
- Auswirkung auf Säule 3a-Limite (Klein vs. Gross).

## Hypothèses
- Standard BVG-Eintrittsschwelle (22'050 CHF).
- Kein komplexer überobligatorischer BVG-Plan.

## Limites
- Nur die Vorsorgebescheinigung ist massgebend.
- Erkennt keine Beitragslücken aus der Vergangenheit.

## Disclaimer
"Die Säule 3a-Limiten können sich von Jahr zu Jahr ändern; überprüfe den gültigen Betrag zum Zeitpunkt der Einzahlung. Dies ist keine offizielle Berechnung."

## Action
"Meinen Status bestätigen"

## Reminder
"Januar: Jährliche Vorsorgebescheinigung überprüfen."

## Safe Mode
Nur informativ.
