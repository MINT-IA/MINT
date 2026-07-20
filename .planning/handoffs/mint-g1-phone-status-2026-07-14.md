# MINT G1 — état court pour téléphone

Date: 2026-07-20

## En une phrase

G1 avance réellement mais n'est pas fini: **25 tickets sur 31 sont GREEN,
6 floors de registre restent ouverts et `G1-COHERENCE-01` ajoute un P0
d'acceptation écran**. G2/G3 ne sont pas autorisés.

## Ce qui vient d'être prouvé

- `G1-SUCCESSION-01`: **GREEN**.
- Commande canonique exacte: RED sémantique **0/10** à `852c124af`, puis
  **10/10 GREEN** à `7849711b3`.
- Runtime complet au SHA poussé exact
  `32aed9f99c87f2aab738d8860b117fc3a3a7ce5e`: Doctor, build production
  flag-off/on, Maestro, seed civil, overlay sans effacement, Patrol
  `native_present`, `absent_write`, mort de processus et `cold_read`.
- Les quatre suites Patrol passent 1/1; les quatre rapports Maestro passent
  1/1. Les témoins seed sont byte-identiques et les processus writer/reader
  sont distincts.
- Les probes bornés font défiler puis confirment l'ancre Succession dans la
  hiérarchie. Les quatre screenshots ont été inspectés et acceptés par le lead.
- Les 69 entrées de `SHA256SUMS` sont vérifiées; données synthétiques seulement,
  sorties brutes non conservées, cleanup et restauration PASS.
- Audits wrapper code/produit/readiness/probe: PASS, zéro P0/P1, sans carousel.

## Sources de vérité

1. `.planning/runtime-evidence/phase-37/ticket-evidence.json`
2. `.planning/STATE.md`
3. `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md`
4. `.planning/runtime-evidence/phase-37/succession-01/runtime-32aed9f99c87-20260720T060411Z/metadata.json`

## État exact

| État | Nombre |
|---|---:|
| GREEN | 25 |
| `ticket_only` | 5 |
| `red_proven` | 1 |
| **Ouverts** | **6** |

Score provisoire: **8.2/10 — NO-GO**.

## Maintenant

1. Fermer `G1-COHERENCE-01` sur l'écran Premier emploi avant de considérer la
   capture Work comme acceptable.
2. Continuer exclusivement les cinq tickets `ticket_only` restants et
   `G1-RUNTIME-01`.
3. Ne pas relancer les audits SUCCESSION-01 déjà PASS.
4. Ne pas confondre cette preuve de succession avec le runtime global
   `G1-RUNTIME-01`, qui reste `red_proven`.
5. Ne jamais démarrer G2/G3 avant 31/31 GREEN, cohérence écran GREEN, score
   ≥9.0 et zéro P0/P1.

Les chemins d'acquisition concernés restent régis par leurs flags et décisions
d'activation propres. Un ticket technique GREEN n'autorise pas une activation
produit globale.

## Pour reprendre dans une nouvelle tâche Codex

```text
Continue exclusivement G1 Ledger Reality Baseline dans
/Users/julienbattaglia/Desktop/MINT.nosync. Lis AGENTS.md puis ce handoff.
Vérifie le registre machine avant toute affirmation. Respecte Mint OS, les
agents permanents, TDD red→green, Doctor, Claude wrapper, Mermaid,
Maestro/Patrol, commits/pushs. Ne démarre pas G2/G3.
```
