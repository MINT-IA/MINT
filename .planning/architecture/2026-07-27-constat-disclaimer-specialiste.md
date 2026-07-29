---
description: Constat §3.5 du hand-off 2026-07-27 — le rapport « 12 endpoints famille » est rejoué et CONFIRMÉ (12 usages exacts du DISCLAIMER de family.py), mais le périmètre réel est plus large — au moins 10 fichiers backend portent « specialiste » sans accent dans des textes user-facing, déjà comptés dans les 263 violations du lint d'accents câblé par #1068.
---

# Constat — « specialiste » sans accent : 12 endpoints famille confirmés, périmètre plus large

Item §3.5 du hand-off `2026-07-27-HANDOFF.md` : « Établir d'abord les
appelants réels ; "12 endpoints famille" vient d'un rapport non rejoué. »

## 1. Le rapport est rejoué et confirmé

`services/backend/app/api/v1/endpoints/family.py:92` définit un `DISCLAIMER`
et le grep mécanique donne **exactement 12** usages :

```bash
grep -c "disclaimer=DISCLAIMER" services/backend/app/api/v1/endpoints/family.py
# -> 12
```

Le chiffre du rapport d'agent tenait. Douze réponses des endpoints famille
portent donc le même texte fautif.

## 2. Le périmètre réel dépasse la famille

« specialiste » sans accent apparaît dans les disclaimers ou textes
user-facing d'au moins **10 fichiers** backend (grep du 2026-07-27) :

`endpoints/precision.py:50` · `endpoints/open_banking.py:90` ·
`endpoints/confidence.py:47` · `frontalier_service.py:515,519` ·
`endpoints/document_parser.py:67` · `document_parser/document_models.py:107`
· `document_parser/lpp_certificate_parser.py:354` ·
`document_parser/tax_declaration_parser.py:155` ·
`fri/fri_display_service.py:33` · `onboarding/minimal_profile_service.py`
(`_DISCLAIMER`).

`\bspecialistes?\b` figure dans les 14 motifs de `accent_lint_fr` — ces
occurrences font partie des **263 violations héritées** mesurées lors du
câblage du lint (PR #1068). Le gate `--added-only` empêche d'en ajouter de
nouvelles ; il ne résorbe pas l'existant.

## 3. Verdict

La question posée (« appelants réels ») est tranchée : 12 usages via une
seule constante pour la famille, plus une dette diffuse dans ≥10 fichiers.
Correction candidate à séquencer en unité de code : corriger les
**constantes DISCLAIMER partagées** d'abord (une constante corrigée = 12
surfaces pour family.py — meilleur ratio), puis la dette diffuse par
fichiers. Aucune décision de Julien requise (orthographe, pas de sens
financier) ; CLAUDE.md TOP rule #2 l'exige déjà.

## 4. Limites

- Le grep porte sur la forme « specialiste » ; d'autres mots aplatis des
  mêmes disclaimers (« personnalisee », « educatif », « verifiees ») ne sont
  pas dans les 14 motifs du lint et n'ont pas été inventoriés ici.
- Les surfaces mobiles (.dart/.arb) n'ont pas été re-comptées — le scan
  complet du lint (263) les couvre.
