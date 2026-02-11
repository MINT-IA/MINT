# Insert: q_employment_status (Statut professionnel)

## Metadata
```yaml
questionId: "q_employment_status"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- L'utilisateur selectionne son statut professionnel dans le wizard.

## Inputs
- Statut professionnel (salarie, independant, chomeur, sans activite lucrative)

## Outputs
- Regime de prevoyance applicable (AVS, LPP, 3a)
- Plafond 3a applicable
- Couvertures automatiques vs a organiser soi-meme

## Hypothèses
- Statut unique (pas de cumul salarie + independant).
- Domicile en Suisse pour l'ensemble des couvertures sociales.

## Limites
- Les cas de pluriactivite (salarie + independant) ne sont pas traites dans le wizard de base.
- Le statut de frontalier a des regles specifiques non couvertes ici.

## Chiffre Choc
"Un independant sans LPP volontaire peut cotiser jusqu'a 36'288 CHF/an au 3a — soit 5x plus qu'un salarie (7'258 CHF). Mais il perd l'assurance invalidite LPP."

## Learning Goals
- Comprendre les 3 regimes : salarie (employe), independant, sans activite lucrative.
- Savoir que le salarie beneficie automatiquement de l'AVS (LAVS art. 3), du LPP (LPP art. 2) et de l'assurance accident (LAA art. 1a).
- Decouvrir que l'independant doit tout organiser lui-meme : AVS, LPP volontaire, IJM, assurance accident.
- Comprendre que le chomage donne droit a l'AC (LACI art. 8) et maintient la couverture LPP pendant 2 ans max.
- Savoir que le sans-activite lucrative cotise quand meme a l'AVS (LAVS art. 10).

## Disclaimer
"Information a caractere educatif. Le regime de prevoyance depend de ta situation specifique. Consulte ta caisse de compensation ou un·e specialiste."

## Sources
- LAVS art. 3, 10 (Cotisations AVS)
- LPP art. 2, 4, 7 (Assujettissement LPP)
- LAA art. 1a (Assurance accident)
- LACI art. 8 (Droit aux indemnites de chomage)
- OPP3 art. 7 (3a independant sans LPP)

## Action
"Explorer les outils adaptes a mon statut"

## Reminder
"En cas de changement de statut professionnel, verifie ta couverture LPP et ton plafond 3a dans les 30 jours."

## Safe Mode
Si dette critique detectee : priorite au desendettement, quel que soit le statut professionnel.
