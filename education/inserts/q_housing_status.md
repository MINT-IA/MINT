# Insert: q_housing_status (Logement : locataire ou proprietaire)

## Metadata
```yaml
questionId: "q_housing_status"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- L'utilisateur indique s'il est locataire ou proprietaire dans le wizard.

## Inputs
- Statut de logement (locataire, proprietaire, heberge)

## Outputs
- Deductions fiscales applicables
- Opportunites EPL (si locataire avec projet immobilier)
- Impact de la valeur locative (si proprietaire)

## Hypothèses
- Residence principale uniquement (pas de residence secondaire ou de rendement).
- Proprietaire = proprietaire de son logement principal.

## Limites
- Les situations de copropriete ou PPE ne sont pas detaillees.
- La valeur locative varie considerablement d'un canton a l'autre.

## Premier Éclairage
"En Suisse, seuls 36% des menages sont proprietaires — le taux le plus bas d'Europe. Pourtant, un proprietaire paie en moyenne 15-25% de moins par mois qu'un locataire equivalent apres 15 ans d'amortissement."

## Learning Goals
- Comprendre que la propriete en Suisse implique un apport minimum de 20% (max 10% du 2e pilier, FINMA circ. 2017/7).
- Savoir que le proprietaire paie l'impot sur la valeur locative (LIFD art. 21 al. 1 let. b) mais peut deduire les interets hypothecaires et les frais d'entretien.
- Decouvrir le mecanisme de l'EPL (encouragement a la propriete du logement) : retrait LPP + 3a pour financer l'apport (LPP art. 30c).
- Comprendre le calcul de la capacite d'emprunt (Tragbarkeit) : charges max 1/3 du revenu brut, au taux theorique de 5%.
- Savoir que le locataire n'a aucune deduction fiscale liee au logement mais conserve sa flexibilite et sa liquidite.

## Disclaimer
"Information a caractere educatif. L'achat immobilier depend de nombreux facteurs personnels. Consulte un·e specialiste en financement immobilier."

## Sources
- FINMA circ. 2017/7 (Normes minimales hypothecaires)
- LIFD art. 21 al. 1 let. b (Valeur locative)
- LIFD art. 32 (Deduction des frais d'entretien)
- LPP art. 30c (EPL)
- OPP2 art. 30d-30g (Modalites EPL)

## Action
"Simuler ma capacite d'emprunt"

## Reminder
"Si tu es locataire avec un projet immobilier, commence a constituer ton apport des maintenant (epargne + 3a)."

## Safe Mode
Si dette critique detectee : priorite au desendettement avant tout projet immobilier.
