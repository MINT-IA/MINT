---
description: Correction — l'instrument qui mesurait la santé du coffre sur simulateur était faussé ; ce qui reste établi, et ce qui ne l'est plus.
---

# Le coffre sur simulateur — et l'instrument qui mesurait mal

## Ce qui reste ÉTABLI

Sur un build simulateur **non signé** (configuration du dépôt depuis le
2026-05-05 : `CODE_SIGNING_ALLOWED[sdk=iphonesimulator*] = NO` dans six
configurations, plus un shim `codesign` no-op), `SecureWizardStore.write` sur
une clé **sensible** (`mint_twin_registry_v1`) rend **false**, et le journal
porte `-34018` (« A required entitlement isn't present »).

Mesuré par un test d'intégration sur la vraie pile, iPhone 17 Pro / iOS 26.2.
`codesign -d --entitlements` sur le `.app` produit ne rend rien : aucun droit
embarqué.

**Conséquence** : sur cette configuration, aucun fait financier ne persiste sur
simulateur — ni le registre du jumeau, ni le coffre canonique. Une marche de
vérification impliquant un fait enregistré y teste une application vide.

## Ce qui N'EST PAS établi, et pourquoi

L'aide `coffreDisponible()` du test d'intégration, ajoutée après la première
mesure, sondait la clé `_mint_sonde_coffre`. Or `SecureWizardStore.write`
commence par `if (!isSensitive(key)) return false;` — et cette clé n'est pas
classée sensible.

**Elle rendait donc `false` quelle que soit la santé du trousseau.** Toutes les
mesures postérieures faites avec cette aide ne mesuraient pas le coffre : elles
mesuraient ma propre garde.

En conséquence, la question « la signature répare-t-elle le trousseau ? » reste
**OUVERTE**. Les essais de signature ont produit soit un build en échec
intermittent (`Command CodeSign failed`), soit une mesure faite avec la sonde
faussée, soit une lecture de journal provenant d'une installation antérieure.

## RE-MESURÉ le 2026-08-14 avec un instrument valide

La sonde emploie désormais `mint_twin_registry_v1`, qui EST classée sensible.
Et surtout, `write`/`read` **lèvent** maintenant sur une clé non sensible au
lieu de rendre `false`/`null` : l'erreur qui m'a trompé ne peut plus se
reproduire en silence.

Verdict : sur la configuration actuelle (build simulateur non signé), le coffre
est **réellement indisponible**. La conclusion d'origine tient — elle est
maintenant établie, plus seulement plausible.

Reste ouvert, et uniquement cela : **la signature répare-t-elle le trousseau ?**
Les essais ont buté sur un échec intermittent de `Command CodeSign`, qui est
exactement la raison de sa désactivation en mai. À traiter dans un lot dédié.

## Ce qu'il faut faire pour trancher

1. Corriger l'aide : sonder une clé **classée sensible**.
2. Rebâtir avec la signature activée, vérifier `codesign -d --entitlements`
   **avant** de conclure quoi que ce soit.
3. Relancer la sonde et lire un journal daté **après** l'installation.

## Contre-arguments

- *« La première mesure suffit, la conclusion tient. »* Pour la configuration
  non signée, oui. Mais elle ne dit rien de la configuration signée, et c'est
  précisément la question posée.
- *« Le `-34018` a disparu après signature, c'est un signe. »* Faible : son
  absence peut venir d'un chemin non exercé, et l'app relancée était parfois
  l'installation précédente.

## Lacunes de données

- La signature simulateur échoue par intermittence (`Command CodeSign failed`),
  ce qui est exactement la raison de sa désactivation en mai. Aucune cause
  racine identifiée pour cette intermittence.
- Le harnais `flutter test integration_test` ne parvient pas à démarrer l'app
  quand la signature est activée, alors qu'un `simctl install` + `launch`
  manuel réussit avec une signature valide.
