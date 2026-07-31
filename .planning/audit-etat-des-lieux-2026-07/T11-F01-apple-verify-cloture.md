---
name: t11-f01-apple-verify-cloture
description: "Clôture du finding P0 T11-F01 (/auth/apple/verify) — réel au SHA gelé 8d059e502, déjà corrigé dans dev (vérification JWKS), + durcissement e-mail non vérifié"
metadata:
  type: audit-closure
  finding: T11-F01
  severity: P0
  verdict: "déjà corrigé"
---

# T11-F01 — `/auth/apple/verify` : instruction et clôture

**TLDR.** Le finding P0 T11-F01 de l'audit 2026-07 (SHA gelé `8d059e502`) était **réel à ce SHA** : le jeton d'identité Apple y était décodé par un `base64` manuel, sans vérification de signature. Il est **déjà corrigé dans `origin/dev`** : le flux vérifie aujourd'hui la signature contre le JWKS d'Apple, plus l'émetteur, l'audience, l'expiration et la liaison du nonce. Un test de non-régression existe déjà. Ce travail ajoute en plus un **durcissement défense-en-profondeur** sur un vecteur résiduel de rattachement par e-mail non attesté vérifié. Verdict : **DÉJÀ CORRIGÉ + durcissement**.

## 1. Le finding tel qu'audité

- **ID** : T11-F01 (backlog TOP-20, thème T11).
- **Énoncé** : rattachement de compte possible sur `/auth/apple/verify` — décodage `base64` manuel du JWT Apple, sans vérification JWKS.
- **Base de l'audit** : SHA gelé `8d059e502` (audit figé le 2026-07-21).

## 2. Instruction — confirmé réel au SHA gelé

Au SHA `8d059e502`, la fonction `apple_verify` contenait (preuve `git show 8d059e502:services/backend/app/api/v1/endpoints/auth.py`) :

- commentaire explicite : « Decode Apple identity token (JWT) **without signature verification (MVP)** » ;
- `import base64` puis `payload_bytes = base64.urlsafe_b64decode(payload_b64)` ;
- contrôle limité à `iss` et `exp` lus depuis un payload **non authentifié**.

Conséquence à ce SHA : un jeton forgé avec un `sub` / `email` arbitraires aurait été accepté. Le finding était donc **valide sur l'artefact audité**.

## 3. État actuel — déjà corrigé dans `origin/dev`

Le correctif `fee1cee48` « fix(auth): verify Apple identity tokens » (2026-06-14) **est un ancêtre de `origin/dev`** mais **n'est pas un ancêtre de `8d059e502`** (l'audit a été figé sur une base qui ne le contenait pas). Preuve :

```
git merge-base --is-ancestor fee1cee48 origin/dev   -> vrai
git merge-base --is-ancestor fee1cee48 8d059e502    -> faux
```

Correctifs de suivi également présents dans `dev` : `d5ea2aae8` (liaison par `sub` stable), `1b805f1f0` (audiences multiples), `6bb210a54` (injection de la clé de signature), `d03c69d85` (blocage de la ré-hydratation d'un compte Apple supprimé), `26d707c43` (message de recréation).

État du code aujourd'hui (`services/backend/app/api/v1/endpoints/auth.py`) :

- `_verify_apple_identity_token` (`auth.py:1376`) exige un nonce, impose `alg=RS256` + `kid`, récupère la clé de signature via le **JWKS d'Apple** (`_APPLE_JWKS_CLIENT.get_signing_key_from_jwt`, `auth.py:143`) ;
- `jwt.decode(...)` (`auth.py:1402`) impose l'audience (configurée par env), l'émetteur `https://appleid.apple.com` (`auth.py:1407`) et `require=[exp, iat, iss, aud, sub]` ;
- liaison du nonce par comparaison `sha256(nonce)` ;
- `grep -c base64 auth.py` = **0** (plus aucun décodage manuel).

## 4. Test de non-régression — déjà présent

`services/backend/tests/test_auth_apple.py::test_apple_verify_rejects_forged_identity_token` envoie un jeton Apple-forme `alg=none` non signé et vérifie le rejet (`400`/`401`). Ce test verrouille précisément le vecteur du P0. Couverture connexe déjà en place : nonce requis / null / non concordant, audience configurée / étrangère, JWKS indisponible (`503`), réutilisation par `sub` stable, blocage de recréation après suppression, conflits e-mail↔`sub`.

## 5. Durcissement ajouté (défense-en-profondeur)

Un vecteur résiduel subsistait dans le thème « takeover » et n'était pas couvert : en intention **login**, si Apple renvoie un e-mail correspondant à un compte mot-de-passe préexistant sans `apple_sub`, le code rattachait **silencieusement** l'identité Apple à ce compte **sans consulter le claim `email_verified`** d'Apple. Un Apple ID géré dont l'e-mail a été fixé par un administrateur tiers sans vérification aurait pu revendiquer le compte d'un tiers.

Correctif minimal :

- helper `_apple_email_is_verified(payload)` (`auth.py:1436`) ;
- garde avant le rattachement automatique (`auth.py:1523`) : refus `409` (`code=apple_email_already_linked`, statut d'audit `apple_email_unverified`) si l'e-mail n'est pas attesté vérifié. Le chemin légitime (e-mail vérifié) reste inchangé.

Tests ajoutés dans `test_auth_apple.py` :

- `test_apple_login_blocks_link_to_password_account_when_email_unverified` (rouge avant, vert après) ;
- `test_apple_login_links_to_password_account_when_email_verified` (garde la voie légitime — prouve le caractère chirurgical).

## 6. Impact contrat

- **API / OpenAPI** : aucune dérive. Régénération de `tools/openapi/mint.openapi.canonical.json` → pas de diff (les réponses `409` sont des `HTTPException` runtime, hors `response_model`).
- **Contrat mobile** : risque faible. La garde réutilise le code `409 apple_email_already_linked` déjà géré côté app ; aucun nouveau code d'erreur, aucune édition Flutter.

## 7. Limites / zone grise (honnêteté)

- L'exploitabilité pratique du vecteur résiduel est **étroite** : Apple renvoie normalement `email_verified` vrai lorsque `email` est présent ; le cas non vérifié relève surtout d'Apple ID gérés. Le durcissement est donc défensif, pas un correctif de P0 vif.
- Le rattachement automatique sur e-mail **vérifié** reste en place (choix produit de consolidation de compte). Le remettre en cause (exiger une action explicite de l'utilisateur) est une décision UX hors périmètre de cette clôture.

## 8. Preuves

- SHA gelé vulnérable : `git show 8d059e502:services/backend/app/api/v1/endpoints/auth.py` (base64, « without signature verification »).
- Ancêtre du correctif : voir §3.
- Code actuel : `services/backend/app/api/v1/endpoints/auth.py:143,1376,1402,1407,1436,1523`.
- Tests : `services/backend/tests/test_auth_apple.py` (16 verts, dont le non-régression forgé + 2 nouveaux).
