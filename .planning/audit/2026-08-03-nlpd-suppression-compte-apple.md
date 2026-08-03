---
description: Audit du cycle de vie du compte (suppression nLPD + reconnexion Apple). Cause exacte de l'impasse device 2026-08-03, correctif backend, et inventaire précis de ce que la suppression purge, de ce qu'elle conserve (et pourquoi).
---

# Cycle de vie du compte — suppression complète (nLPD) + reconnexion Apple propre

**TLDR.** Un utilisateur ayant supprimé son compte Apple pouvait rester
enfermé dehors : la reconnexion Apple répondait « un compte est déjà lié »
(`apple_email_already_linked`) tandis que la re-suppression répondait « n'existe
pas ». Cause exacte reproduite ci-dessous : `users.email` est UNIQUE, donc dès
qu'un compte au même e-mail existe (créé via magic-link / e-mail pendant la
confusion), le chemin *login* court-circuitait sur le jalon de suppression
(`recreate_required`) et le chemin *register* refusait toujours de relier
(`apple_email_already_linked`). Aucune sortie. En parallèle, la suppression
laissait derrière elle plusieurs tables de PII (reçus, journal de faits, mémoire
coach, clés chiffrées, jetons magic-link) et du PII en clair dans le journal
d'audit. Ce document trace la cause, le correctif, et l'inventaire nLPD complet.

---

## 1. Reproduction (backend pur, harnais pytest SQLite in-memory)

Séquence exacte, tous les codes cités depuis la sortie de test :

1. `POST /auth/apple/verify` (register, `allowRecreateAfterDelete=true`, e-mail
   Apple attesté vérifié) → `200`, compte créé.
2. `DELETE /auth/account` (jeton du compte) → `200`, ligne `users` supprimée,
   jalon `auth.account_delete` écrit (hash HMAC du sujet Apple).
3. Un compte au **même e-mail** apparaît (`POST /auth/magic-link/verify` —
   auto-création frictionless, `apple_sub = NULL`, `email_verified = true`).
4. `POST /auth/apple/verify` (login, `allowRecreateAfterDelete=false`) →
   **`409 recreate_required`** (le jalon de suppression court-circuite avant
   toute logique de liaison).
5. `POST /auth/apple/verify` (register, `allowRecreateAfterDelete=true`) →
   **`409 apple_email_already_linked`** (le chemin register refusait
   catégoriquement de relier Apple à un compte e-mail vivant).

Résultat observé : **impasse dure** — les deux chemins Apple renvoient `409`,
et la re-suppression échoue en `require_current_user` (jeton révoqué au delete →
« n'existe pas » côté device).

Ce qui NE reproduit PAS l'impasse (vérifié) : le cycle mono-identité
`register → delete → re-register → delete → re-register` reste vert (le chemin
register recrée un compte frais tant qu'aucun compte homonyme ne subsiste).
C'est l'unicité de `users.email` combinée à un second compte homonyme qui crée
l'impasse.

## 2. Cause exacte

- **Asymétrie login/register.** Sur `apple/verify`, quand un compte est trouvé
  par e-mail avec `apple_sub = NULL` : le chemin *login* reliait Apple si Apple
  atteste l'e-mail vérifié (durcissement T11-F01) ; le chemin *register/recreate*
  refusait **toujours** (`apple_email_already_linked`), même e-mail vérifié.
- **Jalon de suppression permanent.** `_has_deleted_provider_subject` lit le
  journal d'audit `auth.account_delete` (hash HMAC du sujet), qui n'est jamais
  réconcilié. Sur le chemin login il court-circuite en `recreate_required`.
- **Conséquence.** Comme `users.email` est UNIQUE, aucun « compte frais » au
  même e-mail n'est possible : la seule reprise propre est de **reprendre** le
  compte homonyme via un e-mail Apple vérifié. Le code l'interdisait sur le seul
  chemin (register) que le device utilise pour « revenir ».

## 3. Correctif backend (`services/backend/app/api/v1/endpoints/auth.py`)

- **Liaison gouvernée uniquement par la vérification de l'e-mail Apple**, à
  l'identique pour login ET register/recreate. E-mail attesté vérifié → la
  liaison (reprise du compte homonyme) est autorisée → sortie d'impasse.
  E-mail NON vérifié → refus maintenu sur les deux intentions (durcissement
  T11-F01 préservé : un Apple ID géré dont l'e-mail est posé sans vérification ne
  peut pas revendiquer le login e-mail d'un tiers). Le `status` d'audit distingue
  encore l'intention (`apple_email_already_linked` vs `apple_email_unverified`).
- **Anti-résurrection inchangé.** Le jalon `recreate_required` reste en place :
  une identité Apple supprimée ne peut pas recréer une session silencieusement ;
  la reprise exige l'intention explicite « register » (opt-in du device).
- **Contrat mobile inchangé.** L'écran register envoie déjà
  `allowRecreateAfterDelete=true` ; aucun changement Flutter requis pour lever
  l'impasse.

## 4. Inventaire nLPD — deux mécanismes d'effacement

Le codebase utilise **deux** mécanismes d'effacement, choisis par table :

1. **Suppression physique de lignes** (`DELETE`) pour les tables mutables scopées
   `user_id`.
2. **Crypto-shredding** pour les tables **append-only** dont la migration
   `REVOKE UPDATE, DELETE` (p98 `fact_event`, p126 `money_truth_receipts`,
   p111 `projection_audit_records`). Le rôle applicatif ne peut PAS supprimer
   ces lignes : un `DELETE` littéral échouerait en production et laisserait la
   donnée. À la place, détruire le DEK de l'utilisateur (`dek_vault`) rend toute
   valeur chiffrée par ce DEK (dont `fact_event.value_enc`, enveloppe D-26 AES-GCM,
   AAD = user_id) irrécupérable **depuis le système vivant** — c'est le modèle de
   crypto-shred déjà en place (`key_vault.py`, opinion PFPDT Infomaniak 2024).
   Portée honnête : les sauvegardes/WAL conservent le ciphertext (mais pas de clé
   lisible ; elles vieillissent selon la politique de rétention), et un cache DEK
   par processus peut retenir le DEK en clair jusqu'à ~5 min — sans chemin de
   déchiffrement pour un compte supprimé (aucune requête ne repositionne
   `current_user_id` sur un utilisateur supprimé). Ce ne sont pas des propriétés
   introduites ici ; ce sont celles du mécanisme crypto-shred existant.

**Effacé dans la transaction atomique de `DELETE /auth/account`** (ligne `users`
supprimée en dernier, rollback complet si un échec survient) :

| Déjà effacé avant ce correctif | Ajouté par ce correctif |
|---|---|
| profiles, sessions, scenarios, snapshots | coach_insights (mémoire coach) |
| analytics (anonymisé : `user_id → NULL`) | fact_current (read model mutable) |
| login-security, password-reset, email-verification | provenance_records, earmark_tags |
| subscriptions / entitlements / billing tx | commitment_devices, pre_mortem_entries |
| consents, banking_consents, household_members | external_data_sources (sources bancaires) |
| document_embeddings (pgvector), documents | magic_link_tokens (clé = e-mail — vecteur de résurrection silencieuse) |
|  | **dek_vault → crypto-shred** (détruit le DEK ; cache DEK en processus vidé) |

Chaque purge de table mutable s'exécute dans son **SAVEPOINT** (best-effort) :
une table non encore migrée dans un environnement donné est journalisée et
ignorée, sans jamais faire échouer l'effacement atomique du noyau (profils /
sessions / consentements / documents / ligne `users`).

> **Note de revue (Codex, 2026-08-03).** Une première version tentait un
> `DELETE FROM money_truth_receipts` et `DELETE FROM fact_event`. Codex a
> correctement signalé (verdict BLOCK) que ces tables sont append-only avec
> `REVOKE DELETE` : le `DELETE` échoue silencieusement en production sous le rôle
> applicatif, laissant survivre la donnée — « suppression partielle rapportée
> comme complète ». Corrigé : ces tables sont effacées par crypto-shred (DEK)
> pour `fact_event`, et documentées comme conservées-pseudonymisées pour les
> reçus (§5).

**PII en clair purgé du journal d'audit.** Avant ce correctif, le jalon
`auth.account_delete` (et les lignes d'audit antérieures de l'utilisateur)
conservaient `actor_email` et `user_id` en clair pour toujours. Désormais, à la
suppression, toutes les lignes d'audit de l'utilisateur voient `user_id` et
`actor_email` mis à `NULL`, en conservant `user_id_hash` (HMAC-pepper) et les
sujets fournisseurs hachés dans `details_json`.

## 5. Inventaire nLPD — ce qui reste après suppression (et pourquoi)

- **`fact_event` (journal d'événements, append-only).** Lignes conservées (le
  rôle applicatif ne peut pas les supprimer). Les **valeurs** (`value_enc`) sont
  chiffrées par le DEK de l'utilisateur et deviennent irrécupérables dès la
  destruction du DEK (crypto-shred, §4). Reste en base : `user_id` (UUID, la
  table `users` étant supprimée le UUID n'identifie plus directement) + nom de
  champ + ciphertext irrécupérable → pseudonymisé.
- **`money_truth_receipts` (reçus, append-only) — GAP RÉSIDUEL CONNU.** Lignes
  conservées (rôle applicatif sans `DELETE`). `receipt_body` est en **clair**
  (JSON financier : salaire, âge, canton…), NON chiffré par le DEK — donc le
  crypto-shred ne le couvre pas. La **TTL de 30 jours** (`RECEIPT_RESOLVE_TTL`)
  désactive uniquement la **résolution via l'API** ; **la ligne persiste
  indéfiniment en base** et reste lisible pour quiconque a l'accès base
  (opérateurs, sauvegardes, analyse hors-ligne). Le scoping `owner_scope_hash =
  HMAC(user_id)` pseudonymise l'identifiant, pas le corps financier. La
  suppression de compte NE peut PAS effacer ce corps. Voir §8 (recommandation).
- **`audit_events` (lignes de l'utilisateur).** Conservées **sans PII en clair**
  (`user_id`/`actor_email = NULL`), avec uniquement `user_id_hash` (HMAC-pepper,
  non réversible) et les sujets fournisseurs hachés. Motif : traçabilité
  sécurité/conformité + jalon anti-résurrection. Le hash ne ré-identifie pas.
- **`projection_audit_records`, `document_audit_logs`.** Conçues sans PII en
  clair (`user_id_hash` uniquement, append-only pour `projection_audit_records`).
  Conservées comme journaux d'audit ; aucun identifiant en clair.
- **`dek_vault`.** La ligne est supprimée (destruction du DEK). La contrainte FK
  `ON DELETE CASCADE` depuis `users` la retirerait de toute façon ; la
  suppression explicite garantit l'effacement même là où les cascades ne sont
  pas appliquées.
- **Identifiant anonymisé minimal.** Conformément au cadre suisse (délai de
  prescription CO art. 127), un identifiant anonymisé peut subsister à des fins
  d'obligations légales, sans donnée personnelle identifiante — voir
  `privacy_service.delete_user_data` (résumé pédagogique nLPD art. 6 al. 4 /
  art. 32).

### Observabilité par identifiant en clair (intentionnel)

L'endpoint admin d'audit filtre par `user_id` en clair. Après suppression, un
utilisateur effacé n'est plus retrouvable par cet identifiant en clair — c'est
le comportement attendu du droit à l'effacement, pas une régression. Les
utilisateurs vivants conservent leur `user_id`. La corrélation forensique sur un
compte supprimé passe désormais par `user_id_hash` (HMAC), jamais par le clair.

## 6. Tests (backend)

`services/backend/tests/test_auth_apple_lifecycle.py` :

- reprise du compte homonyme vérifié après suppression (sortie d'impasse) ;
- refus maintenu si e-mail Apple non vérifié (T11-F01) ;
- cycle complet register→delete→re-register→delete→re-register vert ;
- suppression physique des tables mutables de PII (coach_insights,
  magic_link_tokens) ;
- crypto-shred du DEK pour les tables append-only : après suppression,
  `get_dek` lève `DEKRevokedError` (valeurs chiffrées irrécupérables) et le reçu
  append-only n'est PAS faussement rapporté comme supprimé ;
- rédaction du PII d'audit + survie du jalon anti-résurrection haché.

## 7. Limites / à surveiller (data gaps)

- Le device n'appelle pas la **révocation du jeton Apple** (`/auth/revoke`
  côté Apple) à la suppression ; Apple peut donc ne pas renvoyer l'e-mail à la
  reconnexion. Le backend gère ce cas (création avec e-mail synthétique), mais
  une révocation explicite serait plus propre — hors périmètre backend seul.
- Le chemin *login* reste en `recreate_required` après suppression : la reprise
  passe par l'écran register. Si le wording device n'oriente pas clairement vers
  « recréer », l'utilisateur peut se croire bloqué — suivi UX (mobile), pas
  backend.
- SAVEPOINT best-effort : une table réellement absente est ignorée. Si une purge
  est régulièrement ignorée en production, c'est le signal d'une migration
  manquante à corriger (ne pas laisser la purge muette masquer une dérive).

## 8. Gap résiduel `money_truth_receipts` — recommandation (hors périmètre P0)

Ce correctif P0 ferme l'impasse Apple et efface les tables mutables + les données
chiffrées (crypto-shred). Il n'efface PAS le `receipt_body` en clair des reçus
append-only (§5). Options pour un suivi dédié (décision produit/sécurité) :

1. **Chiffrer `receipt_body` sous le DEK** (enveloppe D-26, comme `fact_event`).
   Le crypto-shred existant le couvrirait alors automatiquement. Nécessite une
   migration de rétro-chiffrement des reçus existants + adaptation de
   `receipt_store.store/resolve`. Recommandé.
2. **Job de rétention privilégié** qui supprime physiquement les reçus expirés
   (rôle DB avec `DELETE`, hors rôle applicatif), aligné sur la TTL de 30 jours.
   Ferme la fenêtre de rétention indéfinie sans re-chiffrer.

Tant qu'aucune des deux n'est en place, la suppression de compte est **complète
pour tout sauf le corps des reçus**, qui reste en clair pseudonymisé par HMAC.
Ce constat est explicite (pas « rapporté comme complet ») — c'est la raison de
cette page.

## Contre-arguments

- « Relier Apple à un compte homonyme est un vecteur de reprise de compte. » —
  Vrai en général, c'est pourquoi la liaison reste **gouvernée par la
  vérification** : un e-mail Apple attesté vérifié prouve la maîtrise de
  l'adresse (l'utilisateur pourrait de toute façon réinitialiser le mot de passe
  via cet e-mail). Le durcissement ne concernait que l'e-mail NON vérifié, ici
  toujours refusé. Le comportement rejoint celui déjà en place sur le chemin
  login.
- « Le crypto-shred n'est pas durable (sauvegardes, clé maître partagée,
  multi-worker). » — Ce sont les propriétés du mécanisme crypto-shred **existant**
  (`key_vault.py`, opinion PFPDT), pas des régressions introduites ici. La page
  ne surestime pas : elle borne explicitement la portée (§4). Un KMS par-utilisateur
  ou une purge de sauvegardes relèvent d'une décision d'architecture séparée.
- « Purger des tables dans un hotfix P0 est risqué. » — Chaque purge mutable est
  isolée en SAVEPOINT ; un échec (table non migrée) est journalisé sans casser
  l'effacement du noyau. Les tables append-only ne sont PAS supprimées par
  `DELETE` (elles échoueraient) : crypto-shred + documentation. Suite backend
  complète verte (8731 passed).

## Data gaps (revue Codex)

- Le corps des reçus persiste en clair (§8) — connu, documenté, suivi recommandé.
- Le crypto-shred hérite des limites de sauvegarde/clé-maître/cache du mécanisme
  existant (§4) — hors périmètre d'un hotfix auth.
- L'endpoint admin d'audit ne retrouve plus un compte supprimé par `user_id` en
  clair — intentionnel (droit à l'effacement), corrélation par hash seulement.
