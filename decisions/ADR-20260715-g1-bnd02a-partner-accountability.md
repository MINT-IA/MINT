# ADR — G1-BND-02A : accountability des données financières partenaire

**Statut :** Accepted implementation contract — activation blocked
**Date :** 2026-07-15
**Périmètre :** G1-BND-02A/BND-02 uniquement ; aucun G2/G3
**Décideurs requis :** `mint-swiss-brain` puis
`mint-data-ledger-architect`, `mint-data-quest-architect`, backend/mobile et
quality gate

## Décision en une phrase

La voie `manualPartner` peut être construite, derrière des gates default-off,
comme une **déclaration d'autorisation représentée par l'utilisateur agissant**.
Elle n'est jamais qualifiée de consentement direct du partenaire. Aucune
activation n'est permise tant que l'identité réelle du responsable, la garantie
de transfert, la notice partenaire et les autres prérequis externes de cette
décision ne sont pas vérifiés.

## Pourquoi une décision dédiée est nécessaire

L'ADR PROV-02 a fixé le gate ponctuel avant acquisition et la frontière raw-free
du Data Ledger. Il a volontairement laissé BND-02A trancher l'accountability.
Le contrat historique `/api/v1/consents/grant-nominative` ne convient pas : il
conserve un nom en clair, un hash de document et un HMAC d'adresse IP, applique
une base `consent_nLPD_art_6_al_6` générique et appelle la déclaration proxy
« opposable ». Le chemin LPP actuel ne l'appelle d'ailleurs pas.

Les documents du repo nomment aussi plusieurs responsables et contacts
incompatibles. Aucun de ces libellés ne devient vrai par cette ADR. L'identité
juridique et l'adresse de contact doivent être apportées par une preuve externe,
pas déduites du code.

## Sémantique retenue

La voie manuelle utilise exactement :

```text
accountabilityKind = acting_user_partner_authorization_declaration
subjectKind = manualPartner
purpose = one_shot_lpp_extraction
```

Le reçu prouve uniquement que l'utilisateur agissant a déclaré :

1. être autorisé par son/sa partenaire pour cette finalité ;
2. avoir rendu accessible la version exacte de la notice partenaire ;
3. comprendre que cette action ne crée ni compte, ni membership, ni mandat
   général.

Il ne prouve ni l'identité du partenaire, ni un consentement recueilli
directement par MINT, ni une autorisation réutilisable pour une autre finalité.
La validité juridique de cette autorisation représentée doit être confirmée
avant activation. Si elle n'est pas acceptée, la voie reste désactivée ; elle ne
bascule pas silencieusement vers un « intérêt privé prépondérant ».

## Confirmation directe facultative

Un canal ponctuel public peut être ajouté sans création ou liaison de compte :

- notice partageable par lien ou QR ;
- accès direct aux droits et au contact privacy ;
- confirmation facultative de type distinct
  `direct_partner_confirmation` ;
- reçu propre, révocable et effaçable.

Une confirmation directe ultérieure ne transforme jamais rétroactivement un
reçu proxy en consentement direct. La liaison de comptes reste facultative.

## Reçu durable minimisé

Le reçu appartient à un store accountability/consent dédié. Il reste hors Data
Ledger financier, `__provenance`, scénario, dossier, Biography, routes, logs et
analytics. Son enveloppe maximale est :

```text
receiptId
actingPrincipalPseudonym
subjectKind
accountabilityKind
purpose
noticeVersion
policyVersion
declaredAt
expiresAt
revokedAt
erasedAt
```

Un owner pseudonyme ne peut être ajouté que si l'architecture démontre qu'il est
nécessaire à l'invalidation et à l'effacement, sans identité directe. Sont
interdits dans ce store :

```text
subjectName / partnerName / partnerEmail
IP / IP hash
documentSha / declaredDocHash
acquisitionId / filename / OCR / sourceText
valeur financière
grantId ou membership implicite
directPartnerConsent=true sur la voie proxy
```

## Cycle de vie

- La durée est fixe, visible et testée. Une borne maximale de douze mois est le
  choix produit prudent proposé, pas une durée imposée par la nLPD.
- La révocation ou l'expiration invalide les faits importés et tous les résultats
  qui en dépendent jusqu'à une nouvelle déclaration valide.
- La suppression des faits partenaire ou du compte déclenche l'effacement
  anticipé du reçu selon la politique vérifiée.
- Une déclaration manuelle indépendante, avec sa propre provenance, n'est jamais
  supprimée par la révocation d'un import lié.
- Les erreurs, retries et reconstructions ne créent pas deux reçus pour la même
  opération logique.

## Backend et legacy

`/grant-nominative` est **interdit pour LPP en l'état**. Le scope BND-02A doit
nommer un contrat backend versionné et couvrir au minimum : endpoint, schéma,
service, receipt builder, tests et traitement des reçus legacy. Le choix
architecturel est soit :

1. un nouveau contrat minimisé, avec quarantaine/migration explicite du legacy ;
2. la désactivation prouvée de l'ancien endpoint pour LPP.

Aucun reçu legacy contenant nom/hash/IP n'est hydraté dans le nouveau modèle.
L'architecture doit résoudre le cas sans compte obligatoire avant tout code
backend : l'absence d'un JWT utilisateur ne peut ni produire un faux compte, ni
faire tomber le gate, ni justifier un identifiant plus intrusif.

## Gates d'activation fail-closed

Le code peut être développé et testé sous flags default-off. En production,
zéro picker, permission, lecture d'octets, réseau Anthropic ou reçu partenaire
est permis tant qu'un des éléments suivants manque ou est expiré :

1. identité et adresse de contact réelles du responsable, vérifiées ;
2. rôle contractuel réel d'Anthropic et DPA applicable ;
3. pays/régions effectivement utilisés ;
4. garantie de transfert vérifiée et datée ;
5. rétention contractuelle réelle : 30 jours annoncés, sauf preuve ZDR
   applicable au produit et à l'organisation MINT ;
6. notice partenaire publiable, versionnée et sémantiquement équivalente dans
   les six ARB `fr/en/de/es/it/pt` ;
7. canal d'exercice des droits sans compte lié ;
8. AIPD, ou décision documentée et approuvée de non-AIPD ;
9. verdicts ledger, quest, quality et audits externes requis par Mint OS.

Le Swiss–U.S. Data Privacy Framework ne peut pas être annoncé sans entrée
Anthropic active dans la liste officielle au moment du gate. La recherche
active/inactive réalisée le 2026-07-15 n'en a trouvé aucune. ZDR n'est jamais
inféré du simple usage de l'API.

## Information du partenaire

Le contrat non publiable est défini dans
`docs/legal/partner_lpp_notice_contract_v1.md`. Une affirmation de l'utilisateur
« mon/ma partenaire a été informé·e » ne remplace pas une information MINT
concise, accessible et complète. Le canal direct doit fonctionner sans
membership ni compte lié.

## Preuves obligatoires avant GREEN

- proxy sans compte lié : reçu proxy, jamais consentement direct ;
- confirmation directe facultative : type distinct ;
- legacy nom/hash/IP : quarantaine, jamais hydratation ;
- aucun appel LPP à `/grant-nominative` ;
- aucun identifiant, hash, IP ou valeur financière dans le store ;
- notice/version/responsable/transfert/rétention absents : fail closed avant
  picker/octet/réseau ;
- révocation/expiration/effacement : invalidation ciblée et restauration d'une
  déclaration indépendante ;
- droits partenaire utilisables sans account link ;
- six ARB, banned terms, accents FR, no-advice et flags default-off ;
- AIPD ou décision approuvée de non-AIPD avant activation.

La commande RED/GREEN cross-stack exacte doit être inscrite au registre avant
code, avec au minimum le nouveau test backend accountability, la régression
third-party existante et le test lifecycle mobile.

## Sources vérifiées pour cette décision

- [PFPDT — devoir d'informer](https://www.edoeb.admin.ch/fr/devoir-dinformer)
- [PFPDT — externalisation / sous-traitance](https://www.edoeb.admin.ch/fr/externalisation-sous-traitance)
- [PFPDT — communication de données à l'étranger](https://www.edoeb.admin.ch/fr/communication-de-donnees-a-letranger)
- [Liste officielle Swiss–U.S. DPF](https://www.dataprivacyframework.gov/list)
- [Conseil fédéral — le DPF ne couvre que les entreprises certifiées](https://www.zivi.admin.ch/fr/nsb?id=102054)
- [Anthropic — rétention API](https://privacy.anthropic.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
- [Anthropic — portée d'un accord ZDR](https://privacy.anthropic.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to)
- [Anthropic — régions et stockage](https://privacy.anthropic.com/en/articles/7996890-where-are-your-servers-located-do-you-host-your-models-on-eu-servers)

## Conséquence de release

Cette ADR autorise seulement l'architecture et les tests default-off. Elle ne
publie aucune notice, ne valide aucune identité juridique et n'autorise aucun
runtime partenaire. G1 reste NO-GO ; G2/G3 restent interdits.
