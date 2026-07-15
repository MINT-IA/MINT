# ADR — G1-PROV-02 : déclaration partenaire avant acquisition LPP

**Statut :** Accepted pour le ticket PROV-02 au SHA poussé
`30728b8a0671a0b54bcf47807a0c69bac905e6e3` — activation toujours bloquée
**Périmètre :** G1/PROV-02 uniquement ; aucun G2/G3

## Décision

MINT conserve le parcours `manualPartner` **sans exiger de compte partenaire
lié**, mais impose une déclaration explicite, ponctuelle et fail-closed **avant
toute ouverture de caméra/galerie et avant tout transfert**.

Le choix propriétaire n'est plus demandé après l'OCR. Il est fixé avant
l'acquisition et ne peut pas être changé dans la review. Si ce contrat complet
n'est pas implémenté, le fallback d'activation est de bloquer les certificats
partenaire ; il est interdit d'activer le parcours actuel.

Le prédicat de ce parcours est nommé `hasLocalPartnerProfile` et vaut
exclusivement `CoachProfile.conjoint != null`. Il ne faut pas réutiliser
`CoachProfile.hasPartnerContext`, qui décrit actuellement un contexte de statut
civil et peut être vrai sans profil conjoint local. Le prédicat LPP ne dépend ni
d'un compte lié, ni de `HouseholdProvider`, ni de `invitationLevel`, ni d'un
`grantId`.

## Contrat UX avant acquisition

### Profil sans contexte partenaire (`hasLocalPartnerProfile == false`)

- Ne jamais afficher « Tu as un profil couple » ni une action partenaire.
- Afficher un gate self-only : « Ce certificat LPP est-il le tien ? »
- Actions : `Continuer avec mon certificat` et `Annuler`.
- `Annuler` laisse l'écran intact : zéro permission, picker, lecture de bytes,
  consentement, session, requête réseau ou écriture.

### Profil avec contexte partenaire (`hasLocalPartnerProfile == true`)

- Demander : « À qui appartient ce certificat LPP ? »
- Actions : `À moi`, `À mon/ma partenaire`, `Annuler`.
- Le choix `manualPartner` est valable avec un profil partenaire purement
  local. Il ne crée ni invitation, ni compte conjoint, ni autorisation liée.
- Après `manualPartner`, afficher une déclaration non réutilisable pour cet
  essai, avant permission/picker/caméra :
  1. la personne a autorisé l'utilisateur à faire traiter ce certificat par
     MINT ;
  2. elle a été informée de la lecture ponctuelle, du transfert à Anthropic aux
     États-Unis et de la conservation locale chiffrée des seuls chiffres
     confirmés ;
  3. le document brut n'est pas conservé dans le coffre MINT ;
  4. cette déclaration ne relie aucun compte et ne vaut pas mandat général.

Actions : `Je confirme et continue` et `Annuler`. Aucune case précochée, aucun
silence assimilé à un accord.

## Ordre obligatoire des gates

1. Revalider les deux flags LPP default-off.
2. Résoudre `hasLocalPartnerProfile = CoachProfile.conjoint != null`
   localement.
3. Fixer `subject = self | manualPartner`, ou annuler.
4. Si `manualPartner`, obtenir la déclaration ponctuelle décrite ci-dessus.
5. Obtenir les finalités existantes `visionExtraction` puis
   `transferUsAnthropic`. `persistence365d` reste exclue.
6. Seulement alors ouvrir permission/caméra/galerie et lire les bytes.
7. Calculer le SHA-256 sur les **bytes exacts qui seront transmis**, puis le lier
   à l'autorisation ponctuelle avant l'appel `/documents/extract-vision` ; une
   autorisation incomplète interdit l'appel.
8. Retenir uniquement en mémoire, dans `ScanSessionProvider`, une autorisation
   d'acquisition typée contenant `acquisitionId`, `subject`,
   `partnerAttested`, `policyVersion`, `declaredAt` et `documentSha256`. Elle ne
   contient jamais un nom, un compte ou un texte OCR et n'est jamais sérialisée.

`coupleProjection` ne remplace pas cette déclaration : c'est une finalité
globale réutilisable et non une attestation par document. Elle ne sera demandée
que si un scénario de couple la consomme réellement.

## Liaison review → ledger

- La review affiche un badge non éditable `Mon certificat` ou `Certificat de
  mon/ma partenaire`. Une attribution erronée exige `Recommencer`, donc une
  nouvelle acquisition ; aucun basculement post-transfert.
- `LppReviewConfirmation` porte l'autorisation d'acquisition complète issue de
  la session et **dérive** son `subject` de cette autorisation. Le sujet ne peut
  pas être fourni séparément. Une confirmation `manualPartner` n'est valide que
  si l'autorisation ponctuelle est attestée et liée aux bytes du document.
- Le provider reste l'autorité d'identité :
  `owner.kind=manualPartner`, acteur=self, distinct owner pseudonyme,
  `authorization.mode=manualPartnerDeclaration`, `grantId=null`.
- L'autorisation, son SHA-256 et son `acquisitionId` restent volatiles dans la
  `ScanSession`. Ils n'entrent ni dans `_coach_lpp_evidence_v1`, ni dans
  `__provenance`, ni dans Biography, les routes, les logs ou les payloads
  backend. Le ledger durable conserve seulement le mode d'autorisation existant
  sur les faits acceptés.
- La nLPD ne rend pas automatiquement obligatoire un reçu durable par
  document. Avant activation, `G1-BND-02A` doit enregistrer une décision
  juridique/privacy nommée couvrant le rôle de responsable du traitement de
  MINT, le devoir d'information lors de la collecte indirecte (art. 19), le
  transfert à l'étranger et la garantie effectivement vérifiée (art. 16 et
  19(4)), la justification retenue si les droits de la personnalité sont
  touchés, ainsi que la nécessité, la proportionnalité, la rétention,
  l'effacement et les droits du partenaire. Son résultat doit être implémenté.
- Si MINT s'appuie sur une autorisation ou un consentement, un enregistrement
  durable et minimisé, hors Data Ledger financier, doit permettre de prouver
  uniquement que l'utilisateur agissant a déclaré être autorisé. Il ne prouve
  jamais le consentement direct du partenaire. Si une autre justification est
  retenue, la décision doit documenter le mécanisme alternatif
  d'accountability. Aucun `acquisitionId` ou SHA de document n'est conservé par
  défaut ; toute exception doit démontrer sa nécessité, l'absence
  d'alternative moins intrusive, les accès, une durée fixe et l'effacement.
- La déclaration proxy ne remplace pas l'information du partenaire. Avant
  activation, une notice partenaire versionnée doit exposer l'identité et le
  contact MINT, les catégories et finalités, Anthropic comme destinataire/
  sous-traitant, les États-Unis et la garantie de transfert vérifiée, l'absence
  de conservation du brut, la conservation des chiffres confirmés et un canal
  direct d'accès, opposition, retrait et effacement. La liaison de comptes
  reste facultative ; une confirmation directe peut utiliser un canal ponctuel.
- Le ledger financier reste raw-free. Aucun `grantId`, faux compte conjoint ou
  membership implicite ne peut être inféré de `manualPartnerDeclaration`.

## Copy FR de référence

**Self-only**
Titre : « Ce certificat LPP est-il le tien ? »
Corps : « MINT va lire ce document pour t'aider à vérifier les chiffres de ta
prévoyance. »
CTA : « Continuer avec mon certificat » / « Annuler »

**Choix propriétaire**
Titre : « À qui appartient ce certificat LPP ? »
CTA : « À moi » / « À mon/ma partenaire » / « Annuler »

**Déclaration partenaire**
Titre : « Avant de traiter ce certificat »
Corps : « Je confirme que mon/ma partenaire m'a autorisé·e à utiliser ce
certificat dans MINT et a été informé·e qu'il sera lu ponctuellement par
Anthropic aux États-Unis. Seuls les chiffres que je confirme seront conservés
chiffrés sur cet appareil. Le document brut ne sera pas conservé. Cette action
ne relie aucun compte. »
Note : « MINT aide à comprendre ces chiffres. Cela ne constitue pas un conseil
financier personnalisé. »
CTA : « Je confirme et continue » / « Annuler »

## Disposition de promotion — 2026-07-15

`G1-PROV-02` est ticket- et runtime-GREEN au SHA accepté
`30728b8a0671a0b54bcf47807a0c69bac905e6e3`. La preuve exacte couvre le refus
partenaire, l'acquisition partenaire puis self, l'écriture sécurisée, l'arrêt
explicite du processus, la reconstruction froide des deux propriétaires et la
restauration de l'application normale. Les audits code et produit-domaine
bornés passent.

Cette promotion n'est pas une décision d'activation :

- `FeatureFlags.typedLppEvidence` et
  `FeatureFlags.documentLppEvidenceEnabled` restent `false` ;
- l'activation LPP self/partenaire reste **NO** ;
- G1 reste **NO-GO** avec 17 tickets ouverts ; G2/G3 restent interdits ;
- `G1-BND-02` doit encore prouver qu'un fait LPP `manualPartner` reconstruit à
  froid modifie un scénario/recompute production nommé et atteint un rendu
  visible fail-closed ; comme `ForecasterService` lit déjà le
  `rendementCaisse` partenaire, ce gate doit aussi imposer un scope de caisse
  explicite ou mettre cette donnée en quarantaine avant calcul ;
- `G1-BND-02A` doit encore rendre et enregistrer la décision juridique/privacy
  nommée, publier la notice partenaire versionnée et implémenter le mécanisme
  d'accountability qui en résulte. Si l'autorisation/le consentement est la
  justification retenue, un enregistrement durable et minimisé hors ledger
  prouve seulement la déclaration de l'utilisateur agissant, jamais un
  consentement direct du partenaire. Une autre justification doit documenter
  son mécanisme alternatif. Aucun identifiant d'acquisition ni SHA de document
  n'est conservé par défaut ; toute exception reste hors ledger, provenance,
  scénario et dossier et doit être justifiée selon les critères ci-dessus. La
  liaison de comptes demeure facultative et ne doit pas être nécessaire à un
  éventuel canal ponctuel de confirmation directe.

Les rentes conjoint/enfant et les cotisations employé/employeur extraites par
des parseurs existants restent des suivis P2 sans propriétaire de ticket. Elles
ne font pas partie du vocabulaire PROV-02 exact de **13 clés**, sont exclues
avant review/persistance et ne créent ni valeur fausse ni zéro implicite. La
mention « 12 clés » du rerun produit était une erreur de comptage.

Les six ARB `fr/en/de/es/it/pt` doivent porter le même sens, les mêmes finalités,
le même pays destinataire, la même absence de stockage brut et la même absence
de liaison de comptes. La traduction ne doit ni affaiblir « autorisé·e », ni
transformer la déclaration en consentement permanent.

## Tests RED obligatoires

1. Sans `hasLocalPartnerProfile`, aucune copy/action partenaire n'est rendue ;
   le gate self-only précède le consent requester et le picker.
2. Avec contexte partenaire local mais sans compte lié, `manualPartner` est
   disponible ; aucune lecture de `HouseholdProvider`, `invitationLevel` ou
   création de `grantId` n'a lieu.
3. Annuler au choix propriétaire : 0 permission, picker, bytes, hash, session,
   consent, réseau et write.
4. Annuler/refuser la déclaration partenaire : mêmes zéros, y compris si les
   finalités globales avaient déjà été accordées.
5. Refuser `visionExtraction` ou `transferUsAnthropic` après la déclaration :
   0 picker/bytes/réseau/session/ledger.
6. Une autorisation partenaire n'est jamais réutilisée pour une deuxième
   acquisition ; chaque tentative requiert un nouvel `acquisitionId` et une
   nouvelle liaison aux bytes transmis.
7. Une autorisation sans SHA-256 canonique des bytes transmis produit 0 appel
   `/extract-vision`.
8. Le sujet fixé avant acquisition est identique dans session, review,
   confirmation et snapshot ; la review ne propose aucun changement d'owner.
9. Un appel direct `manualPartner` sans autorisation complète issue de la
   session échoue avant load/save/notify/navigation et laisse l'état inchangé.
10. Le snapshot partenaire conserve `grantId=null`, un owner distinct de
    l'acteur self ; aucune autorisation volatile, empreinte documentaire,
    identité directe ni donnée brute n'est sérialisée.
11. ARB parity 6 langues + banned terms + accents FR passent.
12. Maestro/Patrol prouvent les branches self, partenaire sans compte lié,
    refus fail-closed et cold reload, uniquement avec le certificat synthétique.

## Critères GO minimaux

- Les 12 tests ci-dessus sont green après un RED observé.
- Aucun octet ne peut atteindre le processeur avant owner + déclaration
  partenaire + finalités de traitement.
- La branche single-user ne montre aucune promesse de profil couple.
- `manualPartner` reste utile sans compte lié et reste incapable de simuler un
  grant.
- Flags toujours default-off ; activation seulement après runtime frozen-SHA,
  audits `code` et `product-domain`, puis décision G1 nommée.

## Base officielle suisse

Ce contrat est un gate produit prudent, pas un avis juridique. Le PFPDT rappelle
que l'information doit précéder la collecte même lorsque les données sont
collectées auprès d'un tiers, et qu'une communication à l'étranger doit être
portée à la connaissance de la personne concernée :

- [PFPDT — Devoir d'informer](https://www.edoeb.admin.ch/fr/devoir-dinformer)
- [PFPDT — Communication de données à l'étranger](https://www.edoeb.admin.ch/fr/communication-de-donnees-a-letranger)
- [PFPDT — Protection des données dès la conception et par défaut](https://www.edoeb.admin.ch/fr/la-nouvelle-loi-federale-sur-la-protection-des-donnees-du-point-de-vue-du-pfpdt)
