# MINT G1 — état court pour téléphone

Date: 2026-07-17

## En une phrase

G1 avance réellement mais n'est pas fini: **20 tickets sur 31 sont GREEN et
11 hard floors restent ouverts**. G2/G3 ne sont pas autorisés.

## Ce qui vient d'être prouvé

- `G1-BND-01`: **GREEN** au SHA poussé exact `ed5f2db13`.
- Commande de registre identique dans des archives Git physiques: RED
  sémantique **1 pass / 5 échecs** à `d9f93e30b`, puis **6/6 GREEN**.
- Les cinq correspondances historiques sont réconciliées avec un seul lecteur
  production, `Simulator3aScreen`, branché sur
  `CoachProfile.isInDebtCrisis`.
- Le provider non alimenté, son enregistrement et les deux widgets sans appel
  sont supprimés. `Profile` reste uniquement le DTO API/Wizard.
- Une crise causée seulement par le manque de liquidités reçoit un texte
  générique, et l'absence de profil ouvre un vrai CTA vers le diagnostic.
- Audits finaux code et produit/domaine Sonnet: **PASS**, zéro P0/P1; les six
  P2 globaux/cosmétiques restent explicitement suivis sans carousel.
- Les tests utilisent uniquement des profils synthétiques; aucune preuve ne
  conserve de certificat privé, chemin absolu ou log brut.

## Pourquoi l'écran affiche « blocked »

Le badge vient d'un ancien goal technique très large dans l'API Codex. Cette
API ne permet pas à l'agent de le remettre en `in_progress`. Ce badge n'est pas
la source de vérité du repo et n'empêche pas le travail.

Sources de vérité actuelles:

1. `.planning/runtime-evidence/phase-37/ticket-evidence.json`
2. `.planning/STATE.md`
3. `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md`

## État exact

| État | Nombre |
|---|---:|
| GREEN | 20 |
| `ticket_only` | 10 |
| `red_proven` | 1 |
| **Ouverts** | **11** |

Score provisoire: **8.2/10 — NO-GO**.

## Maintenant

1. Commiter/pousser la promotion BND-01 sanitizée et son registre machine.
2. Ne pas relancer de carousel Claude: les deux lentilles finales sont
   archivées avec chaque P2 dispositionné.
3. Continuer uniquement les floors G1 restants, en commençant par le contrat
   Wave 3 `G1-COACH-01` selon le lead.
4. Ne jamais démarrer G2/G3 avant 31/31 GREEN, score ≥9.0 et zéro P0/P1.

Les acquisitions LPP et le plan financier restent désactivés par défaut.
L'import entre comptes reste interdit tant que ses faits externes et son
lifecycle ne sont pas réellement validés.

## Pour reprendre dans une nouvelle tâche Codex

Prompt court:

```text
Continue exclusivement G1 Ledger Reality Baseline dans
/Users/julienbattaglia/Desktop/MINT.nosync. Lis AGENTS.md puis
.planning/handoffs/mint-g1-phone-status-2026-07-14.md et le handoff G1 complet.
Vérifie le registre machine avant toute affirmation. Respecte Mint OS, les
agents permanents, TDD red→green, Doctor, Claude wrapper, Mermaid,
Maestro/Patrol, commits/pushs. Ne démarre pas G2/G3.
```
