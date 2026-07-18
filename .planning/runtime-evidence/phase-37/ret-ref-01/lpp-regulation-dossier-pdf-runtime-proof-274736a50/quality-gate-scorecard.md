# Quality gate — G1 RET-REF LPP regulation dossier/PDF runtime

| gate | result | bounded evidence |
|---|---|---|
| Exact pushed source | PASS | `274736a50bca659579fe26f68ae4e600469e3a9a` verified |
| Patrol runtime | PASS | one native suite, 2/2, zero failures |
| Production composition | PASS | cold reader joins `MintApp` account bootstrap |
| Dossier | PASS | real `/rapport` shows the allowlisted handoff only when resolved |
| Recovery suppression | PASS | missing, mismatch and legacy states omit the dossier handoff |
| PDF runtime | PASS, bounded | production bytes have valid header and nontrivial length |
| PDF text | PASS | real bytes + `pdftotext`, 3/3 ordered/absence/privacy contracts |
| Evidence completeness | PASS | 22/22 expected retained outputs |
| Production-default Maestro | PASS | 1/1 before and 1/1 after, path default-off |
| State lifecycle | PASS | distinct processes, reinstall/state preservation, cleanup/restoration |
| Privacy/minimization | PASS | synthetic only; no sensitive local artifact retained |
| External audits | PASS, bounded | component/bootstrap P0/P1=0; combined runtime audit refused by budget |
| Activation | NO-GO | default-off; other RET-REF obligations remain open |
| RET-REF | `ticket_only` | ticket remains open |
| G1 | OPEN — 8.2/10 | global score and registry disposition unchanged |
| G2 / G3 | FORBIDDEN | no downstream goal may start |

## Fixed-rubric slice score

| dimension | max | score | disposition |
|---|---:|---:|---|
| Data contract | 2.0 | 2.0 | one resolved typed reference feeds sheet, dossier and PDF |
| Swiss correctness | 1.5 | 1.5 | declared/unverified, no applicability or amount inference |
| UX lucidity | 1.5 | 1.4 | complete caveat/questions; punctuation-glyph P2 remains |
| Runtime proof | 1.5 | 1.4 | real route and byte builder; no OS share/viewer claim |
| Automated tests | 1.0 | 1.0 | native 2/2 plus host text 3/3 and checked-in contracts |
| External audit | 1.0 | 0.8 | component deltas pass; combined runtime diff exceeded budget |
| Integration/privacy hygiene | 1.0 | 1.0 | recovery suppression, restoration and allowlist pass |
| Diff discipline | 0.5 | 0.5 | bounded evidence-only promotion |
| **Dossier/PDF slice** | **10.0** | **9.6** | **accepted; not RET-REF/G1 promotion** |

## Gate decision

Accept the bounded dossier/PDF parity slice at **9.6/10** and close only
`pdf_dossier_caveat_parity`. Do not activate the path, promote RET-REF, change
the whole-G1 8.2/10 score, close G1, or start G2/G3.
