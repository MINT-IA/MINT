# Insert: q_avs_gaps (Lacunes AVS)

## Metadata
```yaml
questionId: "q_avs_gaps"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Réponse "Oui" ou "Peut-être" à `q_avs_gaps`.

## Inputs
- Années de cotisation (q_avs_contribution_years)
- Statut civil (q_civil_status)
- Années de cotisation conjoint (q_spouse_avs_contribution_years)

## Outputs
- Réduction estimée de la rente AVS (en %).
- Impact en CHF/mois (estimation).

## Hypothèses
- Carrière complète = 44 années de cotisation (21-65 ans).
- 1 année manquante = -1/44e de rente (~2.3% en moins).
- Rente max célibataire: ~2'450 CHF/mois.
- Rente max couple: ~3'675 CHF/mois.

## Limites
- Seul l'extrait de compte AVS fait foi.
- Ne prend pas en compte le splitting pour les couples.
- Les lacunes peuvent parfois être rachetées (sous conditions strictes).

## Disclaimer
"L'impact sur ta rente est une estimation. Seul ton extrait de compte individuel (IK) de la caisse AVS peut confirmer les lacunes effectives. Tu peux le commander gratuitement sur ahv-iv.ch."

## Action
"Vérifier mes années de cotisation"

## Reminder
"Commander mon extrait AVS si je ne l'ai jamais fait."

## Safe Mode
Informationnel uniquement. Toujours afficher.
