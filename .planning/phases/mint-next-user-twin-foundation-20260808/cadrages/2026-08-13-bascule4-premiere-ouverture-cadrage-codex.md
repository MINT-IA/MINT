---
description: Cadrage Codex GO bascule 4 « Première ouverture pure » (2026-08-13) — l'onboarding legacy est masqué par un owner de route dédié, fail-closed ; la landing active le mode local et ouvre Aujourd'hui ; gate cold-start SANS fixture. Né du retour Julien (TestFlight 2.13.3+80) et de mon angle mort de preuve.
---

# Cadrage Codex — Bascule 4 « Première ouverture pure » (verbatim condensé, 2026-08-13)

## Constat déclencheur
Retour Julien (mobile, 2.13.3+80) : au PREMIER lancement l'app montre l'onboarding legacy intégral (US person, statut d'emploi, état civil, naissance, salaire, montant 3a sans explication, rachat 2e pilier rebouclant sur 3a). Cause mécanique : `/onb` a `owner=RouteOwner.anonymous` (route_metadata.dart:129) et `PreviewShellPolicy.blocksRoute` ne bloque que `coach|explore` (preview_shell_policy.dart:51-56). **L'onboarding n'a jamais été dans le périmètre de la bascule 1.**

## Angle mort de preuve (assumé, entrée du cadrage)
Les 3 reçus runtime (coque 5939d69d3, reset bf3895c77, compte honnête b00650ebd) commencent tous par une fixture `__e2e/...` + « Continuer sans compte », ce qui SAUTE l'onboarding : la pureté prouvée l'était sur un couloir que personne n'emprunte à l'installation. Le gate B4 doit partir d'un COLD START réel, sans fixture ni deeplink.

## Décision — GO, Option A (aucun onboarding neuf)
Parcours préversion : `cold start → landing → disclosure TestFlight → « Continuer sans compte » → Aujourd'hui vide → prochain fait utile`.
- Landing et disclosure CONSERVÉES ; le CTA active explicitement `guestLocal` PUIS ouvre `/home` (aucun transit par le wizard).
- Aucun questionnaire obligatoire avant de voir la coque.
- Aujourd'hui présente l'état honnête : « Je ne sais encore rien de votre situation. » Une seule action suivante à la fois, via les parcours canoniques existants (domicile → état civil → revenu → affiliation LPP → versements 3a → marge attestée quand les préconditions sont réunies).
- Les 7 scènes legacy sont MASQUÉES en préversion, jamais supprimées ici (suppression = chantier writers/legacy séparé).

## Q1 — Premier écran
Promesse : « Comprendre votre situation financière, un fait à la fois. » Sous-texte : « MINT commence sans rien supposer. Ajoutez uniquement ce que vous souhaitez éclairer. » CTA principal « Commencer », secondaire « Continuer sans compte ». Aucune retraite-first, aucun chiffre, aucune promesse de résultat, aucune recommandation ; chaque fait reste corrigeable et supprimable.

## Q2 — Mécanisme (autorité centrale + fermeture)
Ajouter `RouteOwner.legacyOnboarding` et y reclasser `/onb`, `/start` (alias legacy), tous les `/onboarding/*` convergents et tout futur point d'entrée vers `OnboardingShellScreen`. En préversion : `owner == legacyOnboarding → redirection FAIL-CLOSED vers l'entrée préversion` (jamais vers une autre route legacy). Fermeture mécanique exigée : (1) tout chemin ciblant `/onb` porte cet owner ; (2) l'unique builder d'`OnboardingShellScreen` appartient à cet owner ; (3) aucun owner `legacyOnboarding` n'est autorisé par la politique ; (4) tous les aliases fermés dans le registre, aucun appel direct hors registre ; (5) redirection fail-closed ; (6) landing/disclosure conservées, CTA → mode local → Aujourd'hui.
**Utilisateur avec données wizard legacy déjà présentes** : aucune suppression automatique, aucune reprise du wizard, aucune promotion silencieuse vers le jumeau, aucune lecture comme autorité produit — seuls les faits réécrits par les parcours canoniques alimentent le jumeau.

## Q3 — États
Premier lancement pur → landing/disclosure → CTA local explicite → Aujourd'hui, zéro scène legacy · abandon AVANT CTA → relance sur landing, sans mode local implicite · abandon APRÈS CTA → relance sur Aujourd'hui en mode local durable · ancien wizard partiel/complet → même comportement selon l'état local canonique, jamais de reprise legacy · **reset local B2 → retour à la LANDING** (plus `/start` ni `/onb`).

## Q4 — Tests / guards
(1) le builder legacy n'est joignable que par des routes owner `legacyOnboarding` ; (2) tous les aliases convergents portent le même owner ; (3) guard architectural PAR OWNER, jamais par liste manuelle de routes/textes/widgets ; (4) fail-closed sur owner inconnu ; (5) tests router (chaque alias → entrée préversion, aucun cycle de redirection, CTA landing → activation locale → Aujourd'hui) ; (6) tests lifecycle (premier lancement, abandons, relance, reset B2, données historiques) ; (7) guard de câblage : aucun `Navigator`/`go`/`push`/builder direct ne contourne le registre pour atteindre `OnboardingShellScreen`.

## Q5 — Gate runtime OBLIGATOIRE
Cold start réel sur stockage vierge, **sans fixture, sans deeplink, sans état présemé**. Outcomes : (1) premier frame utile = landing/disclosure ; (2) aucune navigation automatique vers `/start` ou `/onb` ; (3) CTA → mode local actif → Aujourd'hui rendu ; (4) kill/relaunch → Aujourd'hui, sans wizard ; (5) reset B2 → landing ; (6) données wizard historiques injectées UNIQUEMENT pour le scénario de migration → ni reprise, ni promotion silencieuse, ni scène legacy.
**Preuve d'absence** : reçu contenant l'EMPREINTE DU REGISTRE au SHA testé (routes, aliases, builder cible, owner) + la trace ORDONNÉE des owners visités. Le gate échoue si un chemin vers le builder legacy n'a pas l'owner, si un owner `legacyOnboarding` apparaît dans la trace runtime, ou si l'empreinte ne correspond pas au SHA. Aucune preuve fondée sur une liste manuelle de 7 scènes ou de leurs copies.

## Beats B4 (8)
`b4_owner_legacy` (owner + application au builder et aliases) · `b4_policy_fail_closed` (interdiction en préversion + redirection canonique) · `b4_entry_local` (landing active le mode local puis ouvre Aujourd'hui) · `b4_lifecycle` (premier lancement, abandons avant/après CTA, relances sans reprise) · `b4_legacy_data_isolation` (données historiques : ni reprise, ni suppression, ni promotion, ni autorité) · `b4_reset_to_landing` (B2 → landing) · `b4_registry_closure` (guard : aucun contournement du registre) · `b4_cold_start_receipt` (stockage vierge, sans fixture, trace d'owners sans legacy).

## Contre-arguments / lacunes (template décision)
- Contre-argument : un onboarding NEUF donnerait une meilleure première impression — rejeté : il rouvrirait un second moteur de collecte concurrent des parcours canoniques (deuxième vérité), pour un bénéfice non prouvé ; l'état vide honnête + « un fait à la fois » suffit à la préversion.
- Lacune : l'écran Aujourd'hui vide en préversion n'a pas encore de « prochain fait utile » séquencé (aujourd'hui il montre l'entrée vertical 3a) — à trancher au contrat : réutiliser l'entrée existante ou introduire un séquenceur minimal.
- Lacune : le reçu de la bascule 2 affirme aujourd'hui « retour entrée onboarding (état zéro légitime) » — B4 le rend FAUX (le reset doit renvoyer à la landing) ; le reçu B2 devra être régénéré après B4.
