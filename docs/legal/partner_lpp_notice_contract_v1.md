# Contrat de notice partenaire LPP v1 — NON PUBLIABLE

**Statut :** contrat d'implémentation ; aucune notice utilisateur n'est publiée
**Version de contrat :** `partner-lpp-notice-contract-v1`
**Date de revue :** 2026-07-15
**Périmètre :** G1-BND-02A/PROV-02 uniquement

## Blocage de publication

Ce document ne contient pas et ne remplace pas la notice partenaire finale. Il
est volontairement non publiable : le repo ne fournit pas une identité et une
adresse de contact du responsable juridiquement vérifiées, ni une garantie et
une rétention Anthropic contractuellement prouvées. Il est interdit de remplir
ces faits avec un nom de marque, une adresse supposée ou un placeholder.

La notice finale n'existe que lorsque les facts externes ci-dessous sont
vérifiés, datés, approuvés et injectés depuis une source juridique canonique.
Sinon le produit échoue avant permission, picker, octet, réseau et création de
reçu.

## Facts externes obligatoires

| fact | preuve attendue | état au 2026-07-15 | comportement si absent |
|---|---|---|---|
| identité juridique du responsable | registre/acte et adresse vérifiés | non résolu | blocage |
| contact privacy réellement opérable | boîte et procédure testées | non résolu | blocage |
| rôle contractuel d'Anthropic | DPA applicable au produit/compte | non prouvé | blocage |
| pays et régions de traitement | configuration et contrat datés | non prouvé | blocage |
| garantie du transfert | mécanisme applicable + analyse/mesures | non prouvé | blocage |
| rétention API | contrat : 30 jours ou ZDR applicable prouvé | non prouvé | blocage |
| AIPD | AIPD approuvée ou décision approuvée de non-AIPD | non résolu | blocage |
| canal de droits | accès sans compte lié testé | non implémenté | blocage |

La présence d'un fournisseur dans un texte historique du repo n'est pas une
preuve. Le Swiss–U.S. DPF ne peut être choisi que si l'entreprise américaine
est certifiée dans la liste officielle au moment du gate. La recherche
active/inactive Anthropic du 2026-07-15 a retourné zéro participant. ZDR ne peut
être annoncé que si un accord applicable à l'organisation et au produit est
fourni ; l'API standard doit sinon annoncer sa rétention contractuelle réelle.

## Contenu obligatoire de la future notice

La notice finale doit être concise, accessible avant l'autorisation représentée
et conservée sous une version immuable. Elle doit exposer sans ambiguïté :

1. l'identité et le contact vérifiés du responsable ;
2. la source indirecte : l'utilisateur agissant ;
3. les catégories de données exactes listées ci-dessous ;
4. la finalité ponctuelle : lire un certificat LPP et produire des explications
   et simulations éducatives ;
5. Anthropic, son rôle contractuel réel et les autres destinataires réels ;
6. chaque État/région effectivement possible et la garantie vérifiée, datée ;
7. la rétention Anthropic réelle, sans promesse ZDR non prouvée ;
8. l'absence de stockage MINT du document brut ;
9. la conservation locale chiffrée des seuls chiffres confirmés et leur cycle
   d'effacement ;
10. l'absence de compte ou de liaison de comptes obligatoire ;
11. les droits d'accès, rectification, opposition/retrait et effacement ;
12. un canal direct utilisable sans account link ;
13. la possibilité de plainte auprès du PFPDT ;
14. la version, la date d'effet et le mécanisme de notification des changements.

## Catégories LPP admises

La notice ne peut employer une catégorie ouverte comme « toutes les données de
prévoyance ». PROV-02 admet exactement les treize catégories canoniques de
`docs/codex/DATA_LEDGER.md` :

1. avoir LPP total actuel ;
2. part obligatoire actuelle ;
3. part surobligatoire actuelle ;
4. salaire assuré annuel ;
5. capacité maximale de rachat ;
6. taux de conversion obligatoire ;
7. taux de conversion surobligatoire ;
8. taux de rendement de la caisse porté par le certificat ;
9. rente annuelle de retraite projetée ;
10. capital de retraite projeté versé en capital ;
11. rente annuelle d'invalidité ;
12. capital d'invalidité distinct ;
13. capital décès.

Les rentes conjoint/enfant et les cotisations employé/employeur sont exclues de
ce contrat. Elles ne deviennent ni valeurs nulles, ni alias, ni faits conservés.

## Sens de l'autorisation

La voie manuelle doit dire que l'utilisateur **déclare être autorisé** et avoir
rendu cette notice accessible. Elle ne doit pas afficher ou sérialiser :

- « le partenaire a consenti directement à MINT » ;
- « déclaration opposable » ;
- un mandat général ou permanent ;
- un consentement déduit d'un mariage, household, invitation ou membership ;
- une autorisation réutilisable pour un autre document ou une autre finalité.

Une confirmation directe facultative utilise un type de reçu différent et ne
modifie pas rétroactivement la nature du reçu proxy.

## Frontière de données

Le document brut transite uniquement pour l'extraction annoncée puis est
éliminé selon le contrat vérifié. MINT ne le place pas dans son coffre, le Data
Ledger, les routes, les logs, les analytics ou les preuves de test. Les chiffres
ne deviennent des faits qu'après confirmation explicite.

Le store accountability ne contient jamais : nom ou email partenaire, IP ou
hash IP, SHA du document, acquisition ID, nom de fichier, OCR/sourceText ou
valeur financière. Il conserve seulement le reçu minimisé défini par
`ADR-20260715-g1-bnd02a-partner-accountability.md`.

## Droits et cycle de vie

Le partenaire doit pouvoir, sans créer ou lier un compte :

- consulter la notice applicable ;
- contacter directement le responsable ;
- demander accès et rectification ;
- s'opposer ou retirer l'autorisation invoquée ;
- demander l'effacement ;
- déposer une plainte auprès du PFPDT.

La révocation, l'expiration ou l'effacement invalide les faits et résultats
issus de cette autorisation. Une déclaration manuelle indépendante n'est pas
supprimée par la révocation d'un import lié. Les copies de la notice expliquent
la durée exacte retenue ; « indéfiniment » ou « tant que nécessaire » ne sont
pas acceptables pour ce parcours.

## No-advice obligatoire

La notice finale conserve ce sens dans les six langues :

> MINT utilise ces données pour une lecture et des simulations éducatives.
> Elles ne remplacent ni une décision de la caisse de pension ni l'examen
> d'un·e spécialiste.

Elle ne promet ni exactitude juridique, ni montant garanti, ni recommandation
personnalisée.

## Versionnement et six ARB

- Une version de notice référence un contenu immuable et une date d'effet.
- Le reçu conserve `noticeVersion` et `policyVersion`, sans copie de PII.
- Toute modification de responsable, destinataire, pays, garantie, rétention,
  catégorie, finalité ou droit crée une nouvelle version et invalide le gate
  tant que les six traductions ne sont pas prêtes.
- `fr/en/de/es/it/pt` doivent être sémantiquement équivalents ; aucune langue ne
  transforme « autorisé·e » en consentement direct ou permanent.
- ARB parity, banned terms, accents FR et no-advice sont des gates automatisés.

## Contrat fail-closed

Chaque entrée acquisition partenaire revalide au runtime : flags default-off,
version de notice, identité/contact, garantie et date de vérification,
rétention, canal de droits et statut AIPD. Une valeur absente, incohérente ou
expirée produit :

```text
permission = 0
picker = 0
documentBytes = 0
networkCalls = 0
accountabilityReceipts = 0
ledgerWrites = 0
```

Le fallback autorisé est de bloquer le parcours partenaire. Il est interdit de
réutiliser `/grant-nominative`, une vieille notice, une affirmation DPF/ZDR ou
un libellé de responsable trouvé ailleurs dans le repo.

## Sources de contrôle

- [PFPDT — devoir d'informer](https://www.edoeb.admin.ch/fr/devoir-dinformer)
- [PFPDT — externalisation / sous-traitance](https://www.edoeb.admin.ch/fr/externalisation-sous-traitance)
- [PFPDT — communication de données à l'étranger](https://www.edoeb.admin.ch/fr/communication-de-donnees-a-letranger)
- [Liste officielle Swiss–U.S. DPF](https://www.dataprivacyframework.gov/list)
- [Conseil fédéral — DPF réservé aux entreprises certifiées](https://www.zivi.admin.ch/fr/nsb?id=102054)
- [Anthropic — rétention API](https://privacy.anthropic.com/en/articles/7996866-how-long-do-you-store-my-organization-s-data)
- [Anthropic — accord ZDR](https://privacy.anthropic.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to)
- [Anthropic — régions et stockage](https://privacy.anthropic.com/en/articles/7996890-where-are-your-servers-located-do-you-host-your-models-on-eu-servers)

## Condition de publication

Le passage de ce contrat à une notice partenaire v1 publiable exige les preuves
externes ci-dessus, le verdict `mint-swiss-brain`, les contrats ledger/quest,
les RED→GREEN cross-stack, Doctor, Mermaid, Maestro/Patrol et les deux audits
Claude via wrapper. Jusque-là, G1 reste NO-GO et G2/G3 restent interdits.
