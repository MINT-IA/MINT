---
description: Cadrage Codex GO Lego C1 « Éclairer ma marge 3a » (2026-08-13) — premier retour coach en lecture-jumeau, surface ponctuelle, enveloppe fermée, outil forcé, claim-checker, quota atomique. Pré-contrat.
---

# Cadrage Codex — Retour coach, Lego C1 (verbatim condensé, 2026-08-13)

## Décision
GO **Lego C1 « Éclairer ma marge 3a »** — PAS de chat démasqué. Surface ponctuelle depuis le vertical 3a : expliquer UNE marge déjà calculée et attestée, lecture seule. **Règle de série : une capacité de lecture par Lego.**

## Q0 — Périmètre
INCLUS : CTA « Éclairer cette marge » depuis le résultat 3a · une question libre bornée au résultat · une réponse · fin du Lego · un seul échange anonyme imputé au quota device existant (3) · flag + kill-switch OFF par défaut.
EXCLU : onglet Coach et /coach/chat démasqués · wizard answers, CoachContext, insights et mémoires legacy · lecture générale des 6 faits · écriture/correction/collecte/navigation générée · recommandation personnalisée.

## Q1 — Frontière exacte
Endpoint dédié `POST /api/v1/coach/twin-read/3a-margin`, payload FERMÉ `extra=forbid` des deux côtés : {contractVersion, purpose: explain_attested_3a_margin, question, consentReceipt{version, grantedAt}, attestation{amountCents, currency, taxYear, state, computedAt, engineVersion, inputsHash, registryHash}}.
NE PARTENT PAS : valeurs scellées des 6 faits, clés Keychain, wizard answers, CoachContext/profileContext, mémoires/insights/historique legacy, identité/provenance locale.
Consentement distant versionné = PRÉCONDITION (sans lui : aucun HTTP, explication locale statique).

## Q2 — Anti-deuxième-vérité
1 outil interne unique `read_attested_3a_margin` · tool_choice FORCÉ au premier appel · tool-result = uniquement l'attestation validée · AUCUN outil write sur cet endpoint · claim-checker déterministe AVANT affichage : chaque montant/%/année/seuil présent dans la sortie outil + sourceRef autorisé ; aucune recommandation/projection/optimisation/donnée nouvelle ; aucune contradiction de state/freshness/engineVersion/hashes ; violation ⇒ réponse rejetée, QUOTA NON CONSOMMÉ, copie locale sûre sans chiffre.

## Q3 — LSFin / copie / jumeau vide
Information pédagogique uniquement ; jamais « tu devrais », produit, rendement promis, optimisation personnalisée. Copie : « Selon les données de ta situation… », année + fraîcheur visibles, limites explicites, CTA uniquement vers correction/complétion. Jumeau vide/incomplet/invalide/trop ancien : AUCUN appel LLM, AUCUN quota, état honnête + renvoi Ma situation.

## Q4 — Tests / guards / backend
Golden contract mobile↔backend (schéma fermé + contractVersion) · tests RED : outil absent/non appelé, outil write demandé, champ legacy injecté, hash incohérent, chiffre non sourcé, recommandation LSFin, jumeau vide, erreur réseau, réponse invalide · backend : EXACTEMENT un outil read-only forcé, allowlist stricte · guard statique : C1 n'appelle jamais /anonymous/chat ni /coach/chat, ne sérialise jamais le profil complet · evals golden (sortie valide, hallucination numérique, conseil interdit, fraîcheur) · logs minimaux (contractVersion, verdict claim-checker, trace outil, statut quota — jamais les faits bruts).

## Q5 — Gate runtime + quota
Reçu lié au SHA : (1) jumeau vide ⇒ renvoi Ma situation, zéro réseau, quota inchangé ; (2) jumeau attesté ⇒ consentement versionné, enveloppe exacte, outil forcé visible dans la trace ; (3) réponse avec source/année/fraîcheur/bornes LSFin ; (4) aucun nombre hors résultat outil ; (5) second essai C1 bloqué localement ; (6) compteur anonyme 3→2 UNIQUEMENT après réponse validée affichable ; (7) refus/timeout/5xx/claim-checker KO ne consomment RIEN.

## Beats C1 (10)
c1_hidden (coach général toujours masqué) · c2_empty_twin (état honnête, zéro appel/quota) · c3_consent (distinct, versionné, révocable ; refus = arrêt local) · c4_closed_envelope (attestation publique + hashes, rien d'autre) · c5_forced_read (endpoint dédié, outil read-only forcé, aucune écriture) · c6_claim_check (contrôle déterministe avant rendu) · c7_valid_render (éclairage borné, sourcé, daté ; aucune relance libre) · c8_failure_atomicity (tout KO = fallback sans chiffre, quota intact) · c9_quota_once (consommation atomique + verrou C1) · c10_runtime_receipt (vide, succès, second essai bloqué, non-consommation sur échec).

## Contre-arguments / lacunes (template décision)
- Contre-argument : un chat complet donnerait plus de valeur perçue immédiate — rejeté : il recréerait la deuxième vérité (contexte legacy) et exploserait le périmètre de preuve.
- Lacune : le consentement « distant versionné » n'existe pas encore côté jumeau (le centre de consentements legacy existe) — à trancher au contrat : réutiliser ConsentService ou créer un consentement dédié twin-read.
