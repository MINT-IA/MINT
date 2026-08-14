---
description: Six affirmations affichées disent que les données ne quittent pas le téléphone, alors que le code qui rendait ça vrai a été supprimé le 2026-04-17. Audit vérifié ligne à ligne, avec ce qui est faux, ce qui est qualifié, et ce qui est mort.
---

# Les affirmations de localité, confrontées au code

**Trouvé le 2026-08-14, en ouvrant l'application** — pas en relisant. Le premier
écran affiché portait une revendication de localité ; en tirant le fil, six
affirmations se sont révélées fausses, dont une sur une fonctionnalité qui
n'existe pas.

## Le fait qui tranche

L'OCR local et le modèle embarqué ont été **supprimés le même jour, le
2026-04-17** :

- `apps/mobile/lib/screens/document_scan/document_scan_screen.dart:669` —
  « Strategy: Claude Vision (**backend**) FIRST, MLKit OCR as fallback », puis
  `:680` — « Local MLKit OCR fallback **was removed 2026-04-17** ». Le chemin
  d'envoi est explicite : `:721` lit les octets, `:729` les encode en base64,
  `:732` les passe en `imageBase64:` au backend. Idem pour les PDF (`:815-819`).
- `apps/mobile/lib/services/slm/slm_engine.dart:1-15` — « SLM Engine —
  **stubbed** […] Removed 2026-04-17 », et
  `apps/mobile/lib/services/feature_flags.dart:72` — `slmPluginReady = false`.

Et le profil part au cloud dès la création d'un compte :
`apps/mobile/lib/providers/auth_provider.dart:1434` appelle
`ApiService.claimLocalData(...)`, dont l'endpoint
`services/backend/app/api/v1/endpoints/sync.py:350` est documenté comme
« migration of local mobile data to the authenticated user's **cloud
profile** ».

## Ce qui est FAUX et AFFICHÉ

Vérifié deux fois : la phrase est fausse **et** sa clé est référencée par un
fichier Dart.

| Clé | Ce qu'elle affiche | Pourquoi c'est faux |
|---|---|---|
| `avsGuidePrivacyNote` | « L'image de ton extrait n'est jamais stockée ni envoyée. L'extraction se fait sur ton appareil. » | L'image est encodée et postée au backend. **La pire** : elle porte sur un extrait AVS. |
| `docScanPrivacyNote` | « L'image est analysée localement (OCR sur l'appareil). » | L'OCR local n'existe plus depuis le 2026-04-17. |
| `vaultPrivacy` | « Tes documents sont analysés localement et ne sont jamais partagés avec des tiers. » | Même chose ; et le fournisseur d'IA est un tiers. |
| `slmPrivacyMessage` | « Le modèle fonctionne 100 % sur ton appareil. Aucune donnée ne quitte ton téléphone. » | Le moteur est un stub. La fonctionnalité **n'existe pas**. |
| `settingsSlmSubtitle` | « Tourne sur ton appareil, même hors ligne » | Idem — et l'entrée n'est PAS derrière `slmPluginReady`. |
| `authGatePrivacyNote` | « Tes données restent sur ton appareil et sont chiffrées. » | Affichée à la porte d'authentification — exactement l'endroit où la synchronisation cloud commence. |

## Ce qui est QUALIFIÉ, donc défendable

- `betaDisclosureBulletNoBank` — « Aucune donnée bancaire stockée chez nous. Les
  données restent sur ton appareil **sauf opt-in explicite**. » La première
  moitié est vraie (aucune connexion bancaire) ; la seconde porte une réserve.
  À revoir, pas à traiter en urgence.

## Ce qui est MORT — faux mais jamais rendu

Ces clés portent les formulations les plus graves (« Rien n'est envoyé sur
Internet », « aucune donnée envoyée (LPD art. 6) ») mais **aucun fichier Dart
ne les référence**. L'application ne les dit donc pas. Elles restent à
supprimer, pour qu'un futur écran ne les ressuscite pas :
`stepOcrLpdBanner`, `stepOcrDisclaimer`, `stepOcrLpdTitle`,
`askMintPrivacyBadge`, `onboardingConsentBody`, `promiseFooter`,
`landingFeature2Desc`, `landingLegalFooter`, `landingLegalFooterShort`,
`consentSecurityMessage`, `authPrivacyReassurance`, `librePassagePrivacyNote`.

## Le garde existe, il passe, et il rate tout

`tools/checks/no_false_privacy_attestation.py` rend `OK`. Ses motifs ne visent
que des tournures étroites — par exemple
`(traitement|parsing).{0,40}(intégralement).{0,20}(sur )?ton appareil` — et
ratent la formulation simple « Tes données restent sur ton appareil », qui est
justement celle qu'on emploie partout.

**Un garde qui rassure en manquant l'occurrence la plus visible est pire qu'un
garde absent** : il transforme une dette connue en dette invisible.

## Contre-arguments

- *« Pour un utilisateur anonyme qui ne crée jamais de compte, les données
  restent effectivement locales. »* Vrai. Mais la phrase est affichée AVANT que
  la personne sache si elle créera un compte, et sans réserve. C'est un
  engagement inconditionnel que le produit ne tient pas dans le cas nominal.
- *« Ce sont des restes de la version d'avant avril, pas un mensonge
  délibéré. »* Vrai aussi, et sans importance pour qui lit l'écran. Une
  affirmation fausse ne se défend pas par son intention.
- *« Trois des pires phrases ne sont pas rendues. »* Exact, et c'est pour ça
  qu'elles sont classées à part plutôt que comptées dans le total. Ne pas
  gonfler le constat le rend plus difficile à écarter.

## Lacunes de données

- Les cinq autres langues n'ont pas été auditées ligne à ligne ; la parité ARB
  laisse supposer les mêmes phrases, mais ce n'est pas vérifié.
- La politique de confidentialité canonique n'a pas été relue : l'écart entre
  ce qu'elle dit et ce que les écrans disent reste à mesurer.
- Ce qu'il faut ÉCRIRE à la place n'est pas tranché ici. Retirer une phrase
  fausse ne demande pas de décision ; en écrire une vraie, si.
