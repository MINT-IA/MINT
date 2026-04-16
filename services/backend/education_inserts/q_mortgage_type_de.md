# Insert: q_mortgage_type (Hypothek)

## Metadata
```yaml
questionId: "q_mortgage_type"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Eigentümer mit Hypothek.

## Inputs
- Aktueller Typ (Festhypothek / SARON / Gemischt)
- Fälligkeit

## Outputs
- Historischer Kostenvergleich.
- Verbundenes Budgetrisiko.

## Hypothèses
- Durchschnittliche Bankmarge.
- SARON-Satz über den Zeitraum stabil (neutrales Szenario).

## Limites
- Zinsprognosen sind unsicher.
- Berücksichtigt keine Vorfälligkeitsentschädigungen (Modell bei Fälligkeit).

## Disclaimer
"Vergangene Entwicklungen lassen keine Rückschlüsse auf zukünftige Zinssätze zu. Die Wahl hängt von deiner Risikobereitschaft ab."

## Learning Goal
Stabilität der monatlichen Rate (Festhypothek) vs. Variabilität (SARON).

## Action
"Strategien vergleichen"

## Reminder
"Fälligkeit - 18 Monate: Mit der Erneuerungsverhandlung beginnen."

## Safe Mode
Priorität auf Stabilität (Festhypothek empfohlen), falls Budget angespannt ist.
