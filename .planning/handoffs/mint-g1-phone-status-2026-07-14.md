# MINT G1 — état court pour téléphone

Date: 2026-07-20

## En une phrase

`G1-RETURN-01` est réellement **GREEN**: le registre est maintenant à **26/31**,
avec **5 floors de registre ouverts**. `G1-COHERENCE-01` reste en plus un P0
d'acceptation écran. G1 reste **NO-GO** et G2/G3 ne sont pas autorisés.

## Ce qui vient d'être prouvé

- Commande canonique RETURN identique: RED sémantique **72/82** à
  `0035356f969236031772bc1956e956a6414c9487`; GREEN initial **82/82** à
  `6427a97722db879d74ccb04bde50d3c75e755112`; réconfirmation **82/82** au
  SHA poussé `d13d032504837cd4bc9233cb6309ebd36b24e4bb`.
- GitHub CI exact-SHA: run `29777377274` **SUCCESS**.
- Runtime complet au SHA poussé exact
  `5eb8a78a2b38caba9ef165ad90f023773bba81f0`: cinq Patrol 1/1 et cinq
  Maestro pour Work save, Housing cancel/no-write, Disability validation
  cancel/no-write, Succession save et Frontalier inline.
- Frontalier sélectionne FR/CH/GE par l'UI de production puis les retrouve après
  relance froide; aucun DataBlock/`returnUri` n'est fabriqué.
- Le runtime RVC lié passe aussi Patrol et Maestro sur le même SHA source.
- Métadonnées, source physique exacte, overlays, témoins de store, hiérarchies,
  screenshots, checksums, données synthétiques, cleanup, restauration et arbre
  source propre: PASS.
- Les audits wrapper archivés n'ont pas de P0/P1 non résolu.

## Sources de vérité

1. `.planning/runtime-evidence/phase-37/ticket-evidence.json`
2. `.planning/runtime-evidence/phase-37/return-01/verification.md`
3. `.planning/runtime-evidence/phase-37/return-01/runtime-5eb8a78a2b-20260720T202301Z/metadata.json`
4. `.planning/STATE.md`
5. `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md`

## État exact

| État | Nombre |
|---|---:|
| GREEN | 26 |
| `ticket_only` | 4 |
| `red_proven` | 1 |
| **Floors de registre ouverts** | **5** |

Ouverts: `G1-COACH-02`, `G1-RET-STATE-01`, `G1-RET-REF-01`, `G1-AVS-02` et
`G1-RUNTIME-01`.

Score provisoire inchangé: **8.2/10 — NO-GO**.

## Maintenant

1. Ne pas confondre RETURN-01 GREEN avec le runtime global
   `G1-RUNTIME-01`, qui reste `red_proven`.
2. Fermer méthodiquement les quatre tickets `ticket_only` puis
   `G1-RUNTIME-01`.
3. Fermer séparément `G1-COHERENCE-01`: l'écran Premier emploi inspecté reste
   incohérent sur les calculs LPP/net, les doublons, les formulations de conseil
   et les bases de projection.
4. Ne pas relancer les audits RETURN déjà PASS sans nouveau diff pertinent.
5. Ne jamais démarrer G2/G3 avant 31/31 GREEN, cohérence écran GREEN, score
   ≥9.0 et zéro P0/P1.

Les flags et décisions d'activation restent indépendants. Un ticket technique
GREEN n'autorise pas une activation produit globale.

## Pour reprendre dans une nouvelle tâche Codex

```text
Continue exclusivement G1 Ledger Reality Baseline dans
/Users/julienbattaglia/Desktop/MINT.nosync. Lis AGENTS.md puis ce handoff.
Vérifie le registre machine avant toute affirmation. Respecte Mint OS, les
agents permanents, TDD red→green, Doctor, Claude wrapper, Mermaid,
Maestro/Patrol, commits/pushs. Ne démarre pas G2/G3.
```
