# Insert: q_has_pension_fund (Affiliation LPP ?)

## Metadata
```yaml
questionId: "q_has_pension_fund"
phase: "Niveau 1"
status: "READY"
```

## Trigger
- Réponse "Non" ou "Incertain" à `q_has_pension_fund`.

## Inputs
- Statut (Salarié / Indépendant)
- Revenu annuel

## Outputs
- Statut probable (Affilié obligatoirement ou non).
- Impact sur plafond 3a (Petit vs Grand).

## Hypothèses
- Seuil d'entrée LPP standard (22'050 CHF).
- Pas de plan lpp surobligatoire complexe.

## Limites
- Seule l'attestation de prévoyance fait foi.
- Ne détecte pas les lacunes de cotisation passées.

## Disclaimer
"Les plafonds 3a peuvent évoluer d’une année à l’autre; vérifie le montant en vigueur au moment du versement. Ceci n’est pas un calcul officiel."

## Action
"Confirmer mon statut"

## Reminder
"Janvier: Vérifier le certificat de prévoyance annuel."

## Safe Mode
Informationnel uniquement.
