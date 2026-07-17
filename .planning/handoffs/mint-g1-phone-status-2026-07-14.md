# MINT G1 — état court pour téléphone

Date: 2026-07-17

## En une phrase

G1 avance réellement mais n'est pas fini: **19 tickets sur 31 sont GREEN et
12 hard floors restent ouverts**. G2/G3 ne sont pas autorisés.

## Ce qui vient d'être prouvé

- `G1-BND-06`: **GREEN** au SHA poussé exact `28d0097f6`.
- Commande de registre identique: RED sémantique physique 6/27 à `9e86539d2`,
  puis **17/17 GREEN**.
- Runtime: Patrol writer, lancement, arrêt processus, reader froid, export Git
  exact, build de l'entrypoint de production, signature/xattr, installation et
  Maestro **1/1**.
- Les 13 étapes sortent à zéro, les 14 logs attendus sont sanitizés, et la
  restauration/privacy est validée sans identifiant appareil ni artifact brut.
- Audit produit/domaine Sonnet puis confirmation finale code Opus: **PASS**,
  zéro P0/P1; les six P2 restent explicitement suivis.
- Le flag compile-time du plan financier reste **false par défaut** et non
  pilotable par le serveur. Aucune activation ni fermeture de G1 n'est
  revendiquée.

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
| GREEN | 19 |
| `ticket_only` | 11 |
| `red_proven` | 1 |
| **Ouverts** | **12** |

Score provisoire: **8.2/10 — NO-GO**.

## Maintenant

1. Indexer la preuve BND-06 sanitizée et son registre machine.
2. Ne pas relancer de carousel Claude: les deux lentilles acceptées sont
   archivées avec chaque P2 dispositionné.
3. Continuer uniquement les floors G1 restants, en commençant par les contrats
   Wave 3 `G1-BND-01` et `G1-COACH-01` selon le lead.
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
