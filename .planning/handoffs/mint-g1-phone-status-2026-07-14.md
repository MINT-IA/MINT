# MINT G1 — état court pour téléphone

Date: 2026-07-14

## En une phrase

G1 avance réellement mais n'est pas fini: **13 tickets sur 31 sont GREEN et
18 hard floors restent ouverts**. G2/G3 ne sont pas autorisés.

## Ce qui vient d'être prouvé

- `G1-PROV-03` code: **GREEN** à `5a772865b`.
- Runtime réel: **GREEN** à `ac74672db`.
- Chaîne runtime: build/install iOS, Maestro flag-off, Patrol writer, arrêt
  processus, Patrol reader froid, deux xcresults 1/1, restauration et Doctor.
- Suite Flutter à ce SHA: analyse 0; **8 899 passés, 33 ignorés, 0 échec**.
- Claude Opus code: **PASS**, zéro P0/P1.
- Claude Opus produit/domaine suisse: **PASS**, zéro P0/P1.
- Production: tax ingestion encore désactivée par défaut; aucune activation
  n'est revendiquée.

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
| GREEN | 13 |
| `ticket_only` | 17 |
| `red_proven` | 1 |
| **Ouverts** | **18** |

Score provisoire: **8.2/10 — NO-GO**.

## Maintenant

1. Indexer et pousser la preuve PROV-03 sanitizée.
2. Faire l'unique rerun architecture Sonnet après réconciliation.
3. Continuer les tickets G1 dans leur ordre de dépendances, notamment la
   persistance LPP self/partenaire manuel puis les grants conjoint.
4. Ne jamais démarrer G2/G3 avant 31/31 GREEN, score ≥9.0 et zéro P0/P1.

Chantier suivant déjà cadré par `mint-data-ledger-architect`:

- PROV02-A: enveloppe LPP typée et atomique pour soi-même.
- PROV02-B: partenaire manuel optionnel, owner distinct, sans compte lié.
- PROV02-C: restart réel, privacy, audits et scorecard.
- Import entre comptes: toujours désactivé jusqu'au lifecycle complet BND-02A.

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
