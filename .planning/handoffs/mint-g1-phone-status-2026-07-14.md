# MINT G1 — état court pour téléphone

Date: 2026-07-17

## En une phrase

G1 avance réellement mais n'est pas fini: **21 tickets sur 31 sont GREEN et
10 hard floors restent ouverts**. G2/G3 ne sont pas autorisés.

## Ce qui vient d'être prouvé

- `G1-COACH-01`: **GREEN** au SHA poussé exact `fec1d4119e`.
- Commande de registre identique: RED sémantique **3 contrôles passés / 7
  échecs** à `c7809198e`, puis **14/14 GREEN** au SHA accepté.
- La vraie chaîne `WidgetRenderer → CoachMessageBubble → CoachChatScreen`
  attend une écriture canonique sérialisée avant notification, état répondu et
  écho factuel.
- Le salaire reste brut annuel avec l'autorité 12/13 périodes existante; LPP et
  3a restent des stocks totaux. Zéro est durable; valeurs hors plafond,
  négatives/non-finies et concurrence LPP stricte échouent avant effet de bord.
- Une panne de persistence reste réessayable et le cold reload retrouve la
  provenance `{userInput, updatedAt, sourceDate:null}`.
- Patrol exact-SHA dédié: **1/1 PASS**. Le screenshot réel MINT Coach a été vu
  et accepté; son overlay DEBUG est explicitement borné et ne prétend pas
  prouver le chrome production par défaut.
- Audits wrapper code et produit/domaine Opus first-pass: **PASS**, zéro P0/P1,
  sans rerun/carousel. Cinq P2 restent explicitement suivis.
- Données uniquement synthétiques; aucun certificat privé, UDID brut, chemin
  local absolu ou xcresult n'est conservé.

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
| GREEN | 21 |
| `ticket_only` | 9 |
| `red_proven` | 1 |
| **Ouverts** | **10** |

Score provisoire: **8.2/10 — NO-GO**.

## Maintenant

1. Commencer uniquement le ticket Wave 4 `G1-FRONT-01` avec le verdict Swiss
   officiel avant le contrat ledger et le câblage mobile.
2. Ne pas relancer Claude pour COACH-01: les deux lentilles first-pass sont
   PASS et chaque P2 est dispositionné.
3. `G1-RUNTIME-01` reste `red_proven`; ne pas le confondre avec le Patrol
   spécifique COACH-01.
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
