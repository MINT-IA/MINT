---
description: Cadrage Codex GO bascule 3 (2026-08-13) — suppression de compte honnête, DEUX tranches ordonnées (B3a état anonyme honnête / B3b suppression connectée transactionnelle), pré-contrat.
---

# Cadrage Codex — Bascule 3 (verbatim condensé, 2026-08-13)

## Décision
GO B3, **une bascule produit, deux PR atomiques** : B3a (état anonyme honnête) puis B3b (suppression connectée transactionnelle durcie mobile+backend).

## Q0 — Périmètre
- ANONYME : « Supprimer mon compte » = non-sens ; jamais affiché sans identité **canoniquement confirmée** (isLoggedIn seul insuffisant — peut être périmé vs jetons réels ; deux entrypoints divergents aujourd'hui : centre de confidentialité + profile_drawer). En préversion → proposer B2. Hors préversion → PAS de reset (contournement quota interdit).
- CONNECTÉ : flux existant INSUFFISANT — ApiService.deleteAccount() contourne le helper DELETE (timeout/refresh/retry 401, api_service.dart:785 vs :595) ; purge locale absorbe ses erreurs (auth_provider.dart:1220) ; deleteAccount() peut retourner true avec purge incomplète (:1013) ; backend best-effort avec résidu money_truth_receipts non crypto-détruit (auth.py:1265).
- QUOTA ANONYME Keychain : purge = B2 preview-only UNIQUEMENT ; une suppression de compte PUBLIQUE préserve le quota device anti-abus → corriger V6-4 qui purge anonymous_session_id/anonymous_message_count.

## Q1 — UI/copie
- Action canonique UNIQUE au centre de confidentialité ; le drawer NAVIGUE (supprime la 2e confirmation divergente).
- 5 états : anonyme+preview → « Repartir à zéro » ; anonyme hors preview → rien ; connecté confirmé → « Supprimer mon compte MINT » ; session périmée → « Se reconnecter pour supprimer le compte » ; serveur-OK/local-incomplet → « Terminer le nettoyage de cet appareil ».
- Copie bornée (résidu backend existant) : « Ton compte MINT et les données associées supprimables depuis nos systèmes seront effacés. Les données enregistrées sur cet appareil seront ensuite nettoyées. Certaines traces strictement nécessaires peuvent être conservées pour la sécurité ou selon les durées applicables. » Jamais « toutes tes données » tant que le résidu demeure.
- Confirmation forte par saisie : SUPPRIMER MON COMPTE. Dialogue rappelle : suppression serveur / déconnexion tous appareils / nettoyage appareil / irréversibilité.

## Q2 — Transaction B3b
1) identité via état auth canonique ; 2) intention durable account_delete_pending liée au userId ; 3) DELETE serveur IDEMPOTENT (refresh + clé d'opération stable) ; 4) reçu serveur durable « compte absent/supprimé » ; 5) purge locale account-scoped à écritures vérifiées ; 6) reset providers ; 7) lever pending PUIS identité/reçu ; succès affiché après seulement.
- Serveur OK/local KO : jamais « échec de suppression » — pending+reçu conservés, réhydratation bloquée, reprise purge au boot.
- Serveur KO : état « suppression non terminée », pas de logout/purge mensongers, retry rejouable.
- Crash/réponse perdue : rejouer la même clé d'opération ; serveur répond succès si compte déjà absent.
- LocalPreviewResetService : réutiliser les PRIMITIVES d'inventaire/purge si extractibles, PAS le workflow B2 (B2 préserve session/consentements/anti-remigration + quarantaine ; B3b supprime credentials/session et clôt l'identité). V6-4 = contrat séparé ou orchestrateur paramétré EXPLICITE.
- Anti-remigration : marqueurs account-scoped supprimés avec le compte ; device-scoped (quota) conservés ; aucun ancien marqueur ne réhydrate un compte supprimé.

## Q3 — Erreurs honnêtes
401 anonyme → état anonyme (pas de suppression) ; 401 session périmée → refresh unique puis « session expirée, reconnecte-toi » ; refresh expiré → reconnexion obligatoire (jamais converti en reset local) ; 5xx → « suppression non confirmée par le serveur », local conservé, retry ; offline/timeout → idem 5xx ; serveur-confirmé/purge-incomplète → « compte supprimé, nettoyage à terminer » + quarantaine + reprise auto.

## Q4 — Tests/guards
Tests : B3a (anonyme, stale isLoggedIn, preview-only, prod sans reset) ; auth (refresh ok/expiré/401 définitif) ; réseau (offline/timeout/5xx/réponse perdue) ; transaction (crash après chaque étape) ; idempotence (double tap, double DELETE, boot, compte déjà absent) ; matrice serveur/local ; purge (account-scoped supprimés, quota+device préservés) ; providers ; backend (statut contractuel, opération rejouable, reçu, inventaire exhaustif tables/objets, money_truth_receipts AVANT toute promesse exhaustive).
Guards : flag+kill-switch OFF par défaut ; storyboard account_delete.storyboard.json ; Journey OS account_lifecycle_delete.json (SHA+preuves fraîches) ; parité routes/ARB ; lint copie interdite « toutes vos données ».

## Q5 — Gate runtime
DELETE réel sur STAGING requis pour B3b : compte jetable dédié, zéro donnée réelle, endpoint staging vérifié, id d'opération consigné (secrets expurgés), preuve avant/après serveur, second DELETE (idempotence), scénario serveur-OK/local-KO + relance, contrôle final d'absence. JAMAIS en production ni sur le compte de Julien. Le sim seul ne prouve pas le backend.

## Beats B3a (8)
1 ouvrir Confidentialité sans identité canonique · 2 « Aucun compte connecté » explicite · 3 jamais présenté comme suppression serveur · 4 en préversion, « Repartir à zéro » proposé séparément · 5 confirmation B2 à portée locale explicite · 6 exécuter B2 · 7 coque anonyme propre · 8 quota anonyme device demeure.

## Tension à trancher au contrat (note Claude)
Beat 8 vs contrat B2 : B2 preview-only PURGE le quota (boucle testeur unique, acté au cadrage B2). Réconciliation attendue : l'invariant « quota demeure » vaut pour le chemin PUBLIC (où aucun reset n'existe) et pour le chemin suppression-de-compte ; le chemin B2 préversion garde sa purge actée. À soumettre à la review du contrat B3a.

## Contre-arguments / lacunes (template décision)
- Contre-argument : durcir le backend (B3b) pourrait retarder la valeur immédiate — mitigé par l'ordre B3a d'abord (mensonge visible corrigé sans dépendance serveur).
- Lacune : l'inventaire exhaustif des tables backend (dont money_truth_receipts) n'est pas encore établi — bloquant pour toute promesse de copie plus ferme, pas pour B3a.
