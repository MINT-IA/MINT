# Remediation — Audit état-des-lieux 2026-07 (Active)

Phase de remédiation dédiée, distincte du milestone produit first-experience.
Ferme les bugs P0/P1 trouvés par l'audit (re-validés sur `dev`, la ligne qui ship)
via le contrat anti-façade : RED → GREEN → preuve runtime (sim/Patrol) → dual-sign
Claude+Codex → close. Tracker : beads (`bd`). Décision spine : dev = produit
(voir ~/MINT-remediation-artifacts/DECISION-20260721-product-spine-dev-vs-g1.md).

## Autorité
Cette phase autorise l'édition des fichiers de remédiation listés dans
`AUTHORIZED_FILES.md`, via l'extension de scope dans tools/checks/journey_os_check.py.
Chaque fermeture = 1 branche + 1 PR + Codex review + CI. Zéro bypass.
