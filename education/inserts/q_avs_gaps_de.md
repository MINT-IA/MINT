# Insert: q_avs_gaps (AHV-Beitragslücken)

## Metadata
```yaml
questionId: "q_avs_gaps"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Antwort "Ja" oder "Vielleicht" bei `q_avs_gaps`.

## Inputs
- Beitragsjahre (q_avs_contribution_years)
- Zivilstand (q_civil_status)
- Beitragsjahre des Partners (q_spouse_avs_contribution_years)

## Outputs
- Geschätzte Rentenkürzung (in %).
- Auswirkung in CHF/Monat (Schätzung).

## Hypothèses
- Vollständige Erwerbsbiografie = 44 Beitragsjahre (21-65 Jahre).
- 1 fehlendes Jahr = -1/44 der Rente (~2.3% weniger).
- Max. Rente ledig: ~2'450 CHF/Monat.
- Max. Rente Paar: ~3'675 CHF/Monat.

## Limites
- Nur der individuelle AHV-Kontoauszug ist massgebend.
- Berücksichtigt kein Splitting für Paare.
- Beitragslücken können unter strengen Bedingungen manchmal nachgezahlt werden.

## Disclaimer
"Die Auswirkung auf deine Rente ist eine Schätzung. Nur dein individueller Kontoauszug (IK) der AHV-Kasse kann die effektiven Beitragslücken bestätigen. Du kannst ihn kostenlos auf ahv-iv.ch bestellen."

## Action
"Meine Beitragsjahre überprüfen"

## Reminder
"Meinen AHV-Auszug bestellen, falls ich das noch nie gemacht habe."

## Safe Mode
Nur informativ. Immer anzeigen.
