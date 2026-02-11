# Politique de confidentialite — MINT

**Derniere mise a jour : fevrier 2026**
**Version : 2.0**

---

## 1. Qui sommes-nous ?

MINT est une application mobile d'education financiere concue pour les resident·e·s en Suisse. Notre mission est simple : t'aider a comprendre ta situation financiere — pilier 3a, LPP, impots, budget, hypotheque, dettes — grace a des outils pedagogiques, des simulations et des explications claires.

MINT est un **outil educatif**. Nous ne sommes pas un intermediaire financier au sens de la LSFin (Loi sur les services financiers). Nous ne gerons pas ton argent, nous ne passons aucun ordre, et nous ne fournissons aucun conseil financier personnalise au sens reglementaire. Nos simulations et suggestions sont fournies a titre informatif et educatif uniquement.

**Responsable du traitement :**
MINT — Swiss Financial Education
Contact protection des donnees : privacy@mint-app.ch

---

## 2. A quoi s'applique cette politique ?

Cette politique de confidentialite s'applique a l'ensemble de l'application MINT (iOS, Android, Web), a nos services backend, et a toute interaction que tu as avec nos outils. Elle decrit quelles donnees nous collectons, pourquoi nous les collectons, comment nous les protegeons, et quels sont tes droits.

Nous respectons la **nouvelle loi federale sur la protection des donnees (nLPD)**, entree en vigueur le 1er septembre 2023, ainsi que son ordonnance d'application (OPDo). Lorsque le Reglement general sur la protection des donnees de l'Union europeenne (RGPD) est applicable — par exemple si tu es resident·e dans l'UE ou l'EEE et que tu utilises notre application — nous respectons egalement ses dispositions.

---

## 3. Quelles donnees collectons-nous ?

### 3.1 Donnees de profil financier

Lorsque tu utilises le wizard MINT (notre questionnaire guide), tu nous fournis des informations telles que :

- **Donnees demographiques** : age, canton de residence, situation civile (celibataire, marie·e, divorce·e, en concubinage), nombre d'enfants
- **Donnees professionnelles** : statut d'emploi (salarie·e, independant·e, au chomage, retraite·e), revenu brut annuel, taux d'activite
- **Donnees de prevoyance** : possession d'un 3e pilier (3a/3b), affiliation LPP, avoir de libre passage, rachats effectues
- **Donnees immobilieres** : proprietaire ou locataire, type d'hypotheque, valeur du bien, dette hypothecaire
- **Donnees budgetaires** : charges mensuelles, loyer, primes d'assurance maladie, epargne mensuelle
- **Donnees de dette** : presence de credits a la consommation, leasings, montants et taux

Ces donnees sont fournies volontairement par toi via le questionnaire. Tu peux choisir de ne pas repondre a certaines questions — dans ce cas, les simulations correspondantes ne seront simplement pas disponibles.

### 3.2 Donnees de simulation

Lorsque tu utilises nos simulateurs (3a, LPP, hypotheque, impots, budget, etc.), les parametres que tu saisis et les resultats calcules sont traites localement. Ces donnees incluent :

- Parametres de simulation (montants, durees, taux)
- Resultats calcules (projections, comparaisons, scores)
- Rapports financiers generes

### 3.3 Donnees techniques

Pour assurer le bon fonctionnement de l'application, nous pouvons collecter :

- Type d'appareil et systeme d'exploitation
- Version de l'application
- Donnees d'utilisation anonymisees (fonctionnalites utilisees, ecrans visites)
- Journaux d'erreurs anonymises

**Important : en Phase 1, nous ne collectons PAS :**
- De donnees bancaires reelles (IBAN, soldes de comptes, transactions)
- De numeros d'assurance sociale (AVS)
- De copies de documents d'identite
- De donnees biometriques

### 3.4 Documents uploades (Phase 2 — a venir)

Dans une phase ulterieure, MINT permettra l'upload de documents tels que des certificats de prevoyance LPP ou des releves bancaires. Voici comment ces documents seront traites :

- Les documents seront traites **exclusivement en memoire** pour en extraire les donnees pertinentes
- **Aucun document ne sera stocke sur un serveur** — le traitement se fait integralement sur ton appareil ou en memoire volatile
- Les donnees extraites sont immediatement anonymisees et les documents sources sont **supprimes apres extraction**
- Tu seras informe·e et devras donner ton consentement explicite avant chaque upload

---

## 4. Pourquoi collectons-nous ces donnees ?

Nous traitons tes donnees pour les finalites suivantes :

| Finalite | Base legale (nLPD) | Details |
|----------|-------------------|---------|
| Education financiere personnalisee | Consentement (art. 6 al. 6 nLPD) | Adapter les explications, simulations et suggestions a ta situation |
| Calculs et simulations | Consentement (art. 6 al. 6 nLPD) | Effectuer des projections 3a, LPP, fiscales, hypothecaires, budgetaires |
| Generation de rapports | Consentement (art. 6 al. 6 nLPD) | Creer des rapports financiers educatifs recapitulatifs |
| Amelioration du service | Interet legitime (art. 6 al. 1 nLPD) | Analyser l'utilisation anonymisee pour ameliorer l'experience |
| Securite et stabilite | Interet legitime (art. 6 al. 1 nLPD) | Detecter et corriger les erreurs techniques |

Nous ne traitons **jamais** tes donnees a des fins de :
- Profilage commercial ou publicitaire
- Vente a des tiers
- Scoring de credit ou decisions automatisees ayant un effet juridique
- Marketing non sollicite

---

## 5. Ou sont stockees tes donnees ?

### 5.1 Stockage local (Phase 1 — actuel)

En Phase 1, **toutes tes donnees personnelles restent sur ton appareil**. Concretement :

- Les preferences et parametres de profil sont stockes via **SharedPreferences** (stockage cle-valeur local)
- Les donnees sensibles (resultats de simulation, donnees financieres detaillees) sont chiffrees via **FlutterSecureStorage**, qui utilise :
  - **Keychain** sur iOS (chiffrement AES-256 par le systeme)
  - **EncryptedSharedPreferences** sur Android (AES-256-GCM via Android Keystore)
- Les rapports generes (PDF) sont stockes dans le repertoire local de l'application

**Aucune donnee personnelle n'est transmise a un serveur externe en Phase 1.** Les appels API entre l'application et notre backend concernent uniquement des calculs generiques (baremes fiscaux, taux legaux) qui ne contiennent aucune donnee personnelle identifiable.

### 5.2 Stockage futur (Phase 2+)

Si un stockage cloud est introduit dans une phase ulterieure, nous :
- T'informerons prealablement et de maniere transparente
- Demanderons ton consentement explicite
- Utiliserons un hebergement en Suisse (conformement a l'art. 16 nLPD sur les transferts transfrontaliers)
- Chiffrerons toutes les donnees en transit (TLS 1.3) et au repos (AES-256)
- Mettrons a jour cette politique de confidentialite avant tout changement

---

## 6. Combien de temps conservons-nous tes donnees ?

| Type de donnee | Duree de conservation | Condition de suppression |
|---------------|----------------------|------------------------|
| Profil financier (local) | Tant que l'app est installee | Desinstallation ou suppression manuelle |
| Resultats de simulation | Tant que l'app est installee | Desinstallation ou suppression manuelle |
| Rapports generes | Tant que l'app est installee | Desinstallation ou suppression manuelle |
| Documents uploades (Phase 2) | Zero — traites en memoire uniquement | Supprimes immediatement apres extraction |
| Donnees d'utilisation anonymisees | Maximum 12 mois | Suppression automatique |
| Journaux d'erreurs | Maximum 30 jours | Suppression automatique |

Tu peux a tout moment supprimer l'ensemble de tes donnees depuis les parametres de l'application (fonction "Supprimer toutes mes donnees"). Cette suppression est **immediate et irreversible**.

---

## 7. Partageons-nous tes donnees ?

**Non.** Nous ne vendons, ne louons et ne partageons pas tes donnees personnelles avec des tiers.

### 7.1 Aucun partage commercial

- Aucune vente de donnees a des annonceurs, courtiers en donnees ou tiers
- Aucun partage avec des institutions financieres, banques ou assurances
- Aucun echange de donnees avec des reseaux sociaux

### 7.2 Partenaires et commissions

MINT peut percevoir des commissions de partenaires (banques, assurances, prestataires 3a) lorsque tu decides volontairement de consulter leurs offres via l'application. Ce modele de monetisation est **totalement transparent** :

- Les partenariats sont clairement identifies dans l'application
- Tes donnees ne sont **jamais transmises** au partenaire sans ton action explicite (clic, redirection)
- Les recommandations pedagogiques de MINT sont independantes des partenariats commerciaux
- Tu es toujours libre d'ignorer les suggestions de partenaires

### 7.3 Sous-traitants techniques

En Phase 1, nous n'utilisons aucun sous-traitant ayant acces a tes donnees personnelles. Si cela change, nous mettrons a jour cette politique et t'en informerons.

### 7.4 Obligations legales

Nous pourrions etre amene·e·s a divulguer des donnees si la loi suisse l'exige (par exemple, sur ordonnance judiciaire). Dans ce cas, nous t'informerons dans la mesure ou la loi nous le permet.

---

## 8. Tes droits

Conformement a la nLPD (art. 25 a 29) et, le cas echeant, au RGPD (art. 15 a 22), tu disposes des droits suivants :

### 8.1 Droit d'acces (art. 25 nLPD)

Tu peux nous demander a tout moment quelles donnees nous detenons a ton sujet. Comme toutes les donnees sont stockees localement sur ton appareil en Phase 1, tu peux les consulter directement dans l'application (section "Mon profil" et "Mes donnees").

### 8.2 Droit de rectification (art. 6 al. 5 nLPD)

Si des donnees te concernant sont inexactes, tu peux les corriger a tout moment directement dans l'application en modifiant tes reponses au questionnaire.

### 8.3 Droit de suppression — "droit a l'oubli" (art. 6 al. 5 nLPD)

Tu peux demander la suppression de toutes tes donnees a tout moment. Dans MINT, tu peux :
- Supprimer des donnees specifiques (par exemple, un rapport ou un resultat de simulation)
- Supprimer l'integralite de tes donnees via le bouton "Supprimer toutes mes donnees" dans les parametres
- Desinstaller l'application, ce qui supprime automatiquement toutes les donnees locales

### 8.4 Droit a la portabilite (art. 28 nLPD)

Tu as le droit de recevoir tes donnees dans un format structure, couramment utilise et lisible par machine. MINT te permet d'exporter :
- Ton profil financier au format JSON
- Tes rapports au format PDF
- Tes resultats de simulation au format CSV

### 8.5 Droit d'opposition (art. 27 nLPD)

Tu peux t'opposer au traitement de tes donnees a tout moment. En pratique, comme le traitement repose sur ton consentement et se fait localement, tu peux simplement :
- Ne pas repondre a certaines questions du wizard
- Desactiver les analytics anonymises dans les parametres
- Supprimer tes donnees et cesser d'utiliser l'application

### 8.6 Droit de ne pas faire l'objet d'une decision automatisee (art. 21 nLPD)

MINT ne prend aucune decision automatisee ayant un effet juridique ou significatif a ton egard. Nos simulations et suggestions sont purement educatives et informatives — elles n'ont aucun impact sur tes droits, tes contrats ou ta situation juridique.

### 8.7 Comment exercer tes droits ?

- **Dans l'application** : la plupart des droits peuvent etre exerces directement dans les parametres de MINT
- **Par email** : privacy@mint-app.ch — nous repondrons dans un delai de 30 jours conformement a l'art. 25 al. 6 nLPD
- **Par courrier** : MINT — Swiss Financial Education, [adresse a completer]

Nous ne te demanderons jamais de frais pour l'exercice de tes droits, sauf en cas de demandes manifestement abusives ou repetitives (art. 25 al. 7 nLPD).

---

## 9. Securite des donnees

Nous prenons la securite de tes donnees tres au serieux. Voici les mesures que nous avons mises en place :

### 9.1 Privacy by Design et Privacy by Default

Conformement a l'art. 7 nLPD, MINT a ete concu des le depart selon les principes de **privacy by design** (protection des donnees des la conception) et de **privacy by default** (protection des donnees par defaut) :

- **Minimisation des donnees** : nous ne collectons que les donnees strictement necessaires aux fonctionnalites educatives
- **Stockage local par defaut** : aucune donnee n'est envoyee a un serveur sans necessite technique absolue
- **Chiffrement par defaut** : les donnees sensibles sont chiffrees localement sans action requise de ta part
- **Pas de compte utilisateur obligatoire** : tu peux utiliser MINT sans creer de compte ni fournir d'email

### 9.2 Mesures techniques

- **Chiffrement local** : FlutterSecureStorage utilise le Keychain (iOS) et le Keystore Android avec chiffrement AES-256
- **Pas de transmission de donnees sensibles** : les calculs generiques (baremes, taux) transitent via HTTPS (TLS 1.2+), mais aucune donnee personnelle n'est transmise
- **Aucun mot de passe stocke en clair** : les eventuels identifiants sont hashes avec bcrypt
- **Dependances a jour** : nous maintenons nos bibliotheques tierces a jour pour corriger les vulnerabilites connues
- **Code ouvert** : notre code source est disponible sous licence MIT, permettant des audits independants

### 9.3 Mesures organisationnelles

- Acces aux systemes restreint au strict necessaire (principe du moindre privilege)
- Revue de code systematique pour toute modification touchant aux donnees
- Tests de securite reguliers
- Sensibilisation de l'equipe a la protection des donnees

---

## 10. Cookies et technologies de suivi

### 10.1 Application mobile

L'application mobile MINT n'utilise **aucun cookie**. Nous n'integrons aucun SDK de tracking tiers (pas de Facebook Pixel, pas de Google Analytics dans l'app mobile).

### 10.2 Version web

La version web de MINT peut utiliser des cookies techniques strictement necessaires au fonctionnement (session, preferences d'affichage). Aucun cookie publicitaire ou de tracking tiers n'est utilise.

### 10.3 Analytics

Si des analytics sont actives, elles sont :
- **Integralement anonymisees** : aucune donnee permettant de t'identifier
- **Agregees** : uniquement des statistiques d'utilisation globales (nombre de simulations lancees, fonctionnalites les plus utilisees)
- **Desactivables** : tu peux desactiver les analytics dans les parametres de l'application
- **Sans transfert hors de Suisse** : les donnees analytiques restent hebergees en Suisse

---

## 11. Transferts internationaux de donnees

En Phase 1, **aucune donnee personnelle n'est transferee hors de Suisse** ni hors de ton appareil.

Si un transfert international devenait necessaire dans une phase ulterieure, nous respecterons les exigences de l'art. 16 nLPD :
- Transfert uniquement vers des pays disposant d'un niveau de protection adequat (liste du Conseil federal)
- A defaut, mise en place de garanties appropriees (clauses contractuelles types, regles d'entreprise contraignantes)
- Information et consentement prealables

---

## 12. Protection des mineur·e·s

MINT est destine aux personnes de 18 ans et plus. Nous ne collectons pas sciemment de donnees personnelles de mineur·e·s. Si nous decouvrons qu'un·e mineur·e a fourni des donnees, nous les supprimerons immediatement.

---

## 13. Modifications de cette politique

Nous pouvons mettre a jour cette politique de confidentialite pour refleter des changements dans nos pratiques, des evolutions legales, ou des nouvelles fonctionnalites.

En cas de modification substantielle :
- Tu seras informe·e via une **notification in-app** lors de ta prochaine ouverture de MINT
- La date de "derniere mise a jour" en haut de ce document sera actualisee
- Un resume des changements sera fourni
- Si les modifications concernent de nouveaux types de traitement, ton **consentement sera redemande**

Nous te recommandons de consulter regulierement cette politique.

---

## 14. Disclaimer — Nature de MINT

**MINT est un outil educatif.** L'application ne constitue pas un conseil financier, fiscal, juridique ou en assurances au sens de la Loi sur les services financiers (LSFin) ni de la Loi sur les etablissements financiers (LEFin).

Les simulations, projections et suggestions fournies par MINT :
- Reposent sur des hypotheses simplifiees et des donnees que tu fournis
- Ne tiennent pas compte de l'integralite de ta situation personnelle
- Peuvent differer des resultats reels en raison d'evolutions legislatives, de conditions de marche ou de ta situation specifique
- Ne remplacent en aucun cas l'avis d'un·e specialiste qualifie·e (conseiller·e fiscal·e, planificateur·rice financier·e, notaire, etc.)

Avant toute decision financiere importante, nous te recommandons de consulter un·e specialiste qualifie·e.

---

## 15. References legales

Cette politique de confidentialite est etablie en conformite avec :

- **nLPD** — Loi federale sur la protection des donnees du 25 septembre 2020 (entree en vigueur le 1er septembre 2023)
- **OPDo** — Ordonnance sur la protection des donnees (RS 235.11)
- **RGPD** — Reglement (UE) 2016/679, dans la mesure ou il est applicable
- **LSFin** — Loi sur les services financiers (pour le disclaimer educatif)
- **LPD precedente** — Loi federale sur la protection des donnees du 19 juin 1992 (abrogee, pour reference historique)

---

## 16. Contact

Pour toute question concernant cette politique de confidentialite ou le traitement de tes donnees :

- **Email** : privacy@mint-app.ch
- **Objet recommande** : "Demande protection des donnees — [ton prenom]"
- **Delai de reponse** : 30 jours maximum (art. 25 al. 6 nLPD)

Si tu estimes que tes droits n'ont pas ete respectes, tu peux deposer une reclamation aupres du **Preopose federal a la protection des donnees et a la transparence (PFPDT)** :
- Site web : www.edoeb.admin.ch
- Adresse : Feldeggweg 1, 3003 Berne

---

*Cette politique est redigee en francais. En cas de divergence avec une traduction, la version francaise fait foi.*

*MINT — "Juste quand il faut : une explication, une action, un rappel."*
