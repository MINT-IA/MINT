# G1-FRONT-01 — Verdict Swiss-domain sur les juridictions frontalières

**Date de vérification :** 2026-07-17
**Rôle :** `mint-swiss-brain`
**Périmètre :** France–Suisse, emploi salarié privé, orientation éducative uniquement

## 1. Verdict

| Élément | Verdict |
|---|---|
| Contrat cible `residenceCountry + workCountry + workCanton`, tous distincts, typés, nullables et fail-closed | **PASS conditionnel** |
| Implémentation actuellement visible | **NO-GO** |
| Calcul fiscal actuel par taux cantonaux plats | **NO-GO** |
| Jauge fiscale universelle de « 90 jours » | **NO-GO — juridiquement erronée** |
| Comparaison automatique de charges CH/France | **NO-GO** |
| Affichage éducatif sans résultat lorsque la juridiction manque | **PASS requis** |

Le contrat n’est acceptable que si :

1. aucune juridiction n’est déduite du permis G, de la nationalité, du canton de résidence ou du statut `frontalier` ;
2. le canton de travail est obligatoire lorsque `workCountry == CH` ;
3. les trois faits incomplets ou périmés ferment toute conclusion fiscale ;
4. l’application identifie seulement **l’instrument potentiellement applicable**, jamais un résultat fiscal personnel sur la base de ces trois faits ;
5. les règles fiscales et les règles d’assurances sociales restent deux moteurs séparés ;
6. l’année légale et les faits d’emploi supplémentaires sont requis avant toute précision.

---

## 2. Constats sur le live

### 2.1 Provider-island

`apps/mobile/lib/screens/frontalier_screen.dart` :

- ne lit ni `CoachProfileProvider`, ni `CoachProfile`, ni le Data Ledger ;
- lance trois calculs dès `initState()` ;
- initialise silencieusement :
  - canton de travail `GE` ;
  - salaire mensuel `CHF 7’000` ;
  - état civil « célibataire » ;
  - `180` jours au bureau ;
  - `40` jours de télétravail ;
  - résidence `France`.

Ces valeurs ressemblent à des faits connus et produisent immédiatement des résultats. Elles sont en réalité des hypothèses inventées.

### 2.2 Gate insuffisant

`gateFrontalier()` considère le parcours prêt avec seulement :

- `residencePermit == G`, ou
- `employmentStatus == frontalier`.

Un permis G est un fait migratoire. Il ne détermine pas :

- la résidence fiscale conventionnelle ;
- le pays réel d’exercice ;
- le canton de travail ;
- l’application de l’accord de 1983 ;
- le régime de télétravail ;
- le barème d’impôt à la source ;
- l’affiliation sociale.

### 2.3 Résultats actuels non acceptables

`ExpatService` utilise notamment :

- des taux plats par canton sans table officielle annuelle ;
- un facteur matrimonial approximatif ;
- un facteur approximatif par enfant ;
- un repli silencieux à `13 %` ;
- une règle universelle de `90 jours` ;
- des taux sociaux étrangers approximatifs ;
- un classement « charges moins élevées ».

Ces mécanismes ne doivent pas être présentés comme une estimation fiscale individuelle.

Le commentaire « barème C » est également trop large : le barème C concerne notamment les personnes mariées ou en partenariat enregistré dont le conjoint perçoit aussi certains revenus. Il n’est pas le barème générique de tout frontalier.

---

## 3. Sources officielles vérifiées

Toutes les sources ci-dessous sont primaires ou publiées par l’autorité administrative compétente.

| Instrument/source | Autorité | Date / état vérifié | Portée |
|---|---|---|---|
| [Convention fiscale franco-suisse du 9 septembre 1966](https://www.fedlex.admin.ch/eli/cc/1967/1079_1119_1113/fr) | Confédération suisse, Fedlex | Consolidée ; consultée le 2026-07-17 | Règle générale, notamment emploi salarié art. 17 |
| [Page officielle AFC « France »](https://www.estv.admin.ch/fr/france) | AFC/SFI | Avenant entré en vigueur le 2025-07-24 | Index officiel des instruments applicables |
| [Avenant du 27 juin 2023, publié par décret n° 2025-838](https://www.legifrance.gouv.fr/jorf/id/JORFTEXT000052129841) | République française, Journal officiel | Entré en vigueur le 2025-07-24 | Télétravail fiscal jusqu’à 40 % du temps annuel |
| [Décret français de mise en œuvre n° 2025-1370](https://www.legifrance.gouv.fr/jorf/id/JORFTEXT000053177717) | République française | Applicable dès le 2026-01-01 | Mise en œuvre et collecte employeur du régime pérenne |
| [Accord amiable du 29 avril 2026](https://www.estv.admin.ch/fr/newnsb/ffQRiL8J5nR6) | SFI/AFC | Publié le 2026-05-01 | Interprétation du régime 2023 désormais en vigueur |
| [Fiche AFC 2026 — hors régime de l’accord de 1983](https://www.estv.admin.ch/dam/fr/sd-web/Hy-Y-kaO7eLV/int-laender-fr-dba-exemplare-ai-cdi-20260429-fr.pdf) | AFC/SFI | 2026-05-01 | Exemples Genève et décompte 40 % / missions |
| [Accord frontalier du 11 avril 1983](https://www.estv.admin.ch/dam/fr/sd-web/GWaZ7OclQkSn/int-laender-fr-accord-frontaliers-19830411-fr.pdf) | Suisse et France | En vigueur depuis le 1986-12-18 | Huit cantons ; imposition de résidence sous conditions |
| [Attestation 2041-AS et huit cantons](https://www.impots.gouv.fr/international-particulier/questions/je-viens-de-debuter-une-activite-salariee-en-suisse-suis-je) | DGFiP | Publié le 2026-03-09 | Mise en œuvre française et retours réguliers |
| [BOFiP — traitements et salaires franco-suisses](https://bofip.impots.gouv.fr/bofip/3149-PGP.html/identifiant%3DBOI-INT-CVB-CHE-10-20-60-20121226) | DGFiP | Doctrine officielle consultée le 2026-07-17 | Articulation CDI / accord de 1983 |
| [Accord amiable du 30 juin 2023 pour l’accord de 1983](https://www.estv.admin.ch/dam/fr/sd-web/qiVpWEIFC3TA/int-laender-fr-dba-ai-1983-20230630-fr.pdf) | Autorités compétentes suisse et française | Effet depuis le 2023-01-01 | Télétravail et missions dans le régime des huit cantons |
| [Statut de quasi-résident](https://www.ge.ch/demande-rectification-taxation-ordinaire-ulterieure/determiner-statut-quasi-resident) | Administration fiscale genevoise | Mis à jour le 2026-04-23 | Seuil et revenus mondiaux du ménage |
| [Barème C de l’impôt à la source](https://www.ge.ch/bareme-c-impot-source) | Administration fiscale genevoise | Mis à jour le 2026-04-23 | Champ réel du barème C |
| [Barèmes genevois 2026](https://www.ge.ch/document/baremes-2026-perception-impot-source) | Administration fiscale genevoise | Année fiscale 2026 | Tables A/B/C/H officielles |
| [Télétravail et assurances sociales](https://www.bsv.admin.ch/fr/teletravail) | OFAS | État publié le 2025-09-12 | Accord social distinct, moins de 50 % |
| [Accord-cadre de sécurité sociale](https://www.bsv.admin.ch/dam/fr/sd-web/TbzCLlzKxlGJ/Telework%20FA%20and%20explanatory%20notes_FR.pdf) | OFAS / États signataires | Applicable depuis le 2023-07-01 | Demande, conditions et attestation A1 |
| [Guide nLPD — mesures techniques et organisationnelles](https://www.edoeb.admin.ch/dam/fr/sd-web/eVhrh8wY3QcR/leitfaden_tom.pdf) | PFPDT | Consulté le 2026-07-17 | Proportionnalité, finalité, exactitude et sécurité |
| [Communication de données à l’étranger](https://www.edoeb.admin.ch/fr/communication-de-donnees-a-letranger) | PFPDT | Consulté le 2026-07-17 | LPD art. 16–19 |
| [Analyse d’impact relative à la protection des données](https://www.edoeb.admin.ch/fr/analyse-dimpact-relative-a-la-protection-des-donnees-personnelles) | PFPDT | Consulté le 2026-07-17 | Risque élevé, LPD art. 22–23 |

---

## 4. Instruments contrôlant les conclusions

### 4.1 Résident français travaillant à Genève

Genève ne fait pas partie des huit cantons couverts par l’accord de 1983.

Pour un emploi salarié privé ordinaire, l’orientation est donc :

1. convention fiscale de 1966, art. 17 ;
2. avenant de 2023 pour le télétravail ;
3. droit suisse et genevois d’imposition à la source ;
4. obligations déclaratives françaises et mécanisme conventionnel d’élimination de la double imposition.

L’accord franco-genevois de 1973 concerne la compensation financière entre autorités. Il ne doit pas être présenté comme la règle attribuant personnellement l’impôt du salarié.

**Conclusion produit autorisée :**

> « Genève ne relève pas de l’accord frontalier de 1983. Pour un emploi salarié privé, la convention franco-suisse et les règles genevoises orientent généralement le salaire vers une imposition en Suisse. Les conditions de ton emploi, du télétravail et de ta situation fiscale restent à confirmer. »

MINT ne peut pas en déduire :

- un barème A/B/C/H ;
- un taux ;
- une taxation ordinaire ultérieure ;
- un droit à déduction ;
- un montant d’économie ;
- une éligibilité 3a.

### 4.2 Résident français travaillant dans un canton de l’accord de 1983

Cantons concernés :

- Berne ;
- Soleure ;
- Bâle-Ville ;
- Bâle-Campagne ;
- Vaud ;
- Valais ;
- Neuchâtel ;
- Jura.

L’accord de 1983 attribue en principe l’imposition des rémunérations à l’État de résidence si la personne remplit la définition conventionnelle du travailleur frontalier. Le retour en France « en règle générale chaque jour », les précisions de 2005 et l’attestation de résidence 2041-AS sont des éléments de contrôle.

Ainsi, `residenceCountry=FR`, `workCountry=CH`, `workCanton=VD` ne suffit pas à conclure « imposé en France ». Cela sélectionne seulement un **candidat instrument 1983**.

### 4.3 Télétravail fiscal franco-suisse

Le régime actuellement applicable ne repose pas sur un seuil universel de 90 jours.

L’avenant du 27 juin 2023 :

- est entré en vigueur le 24 juillet 2025 ;
- est mis en œuvre dans le régime courant depuis le 1er janvier 2026 ;
- permet, dans son champ, de considérer les activités à domicile comme exercées auprès de l’employeur dans la limite de **40 % du temps de travail par année civile** ;
- prévoit qu’au-delà de la limite, les règles ordinaires de l’art. 17 s’appliquent dès le premier jour de télétravail ;
- comporte des règles particulières pour les missions temporaires.

Pour 2023–2025, les accords amiables transitoires et interprétatifs doivent être conservés comme instruments historiques. Le moteur doit donc sélectionner ses règles par `legalYear`.

Le nombre de jours correspondant à 40 % dépend du temps de travail annuel. Il ne peut pas être remplacé par une constante `90`.

### 4.4 Assurances sociales

Le cadre social est indépendant de la fiscalité.

Pour une relation France–Suisse admissible :

- moins de 25 % : procédures ordinaires de coordination ;
- de 25 % à 49,9 % : maintien possible dans l’État de l’employeur sous les conditions de l’accord-cadre, sur demande ;
- une attestation A1 est nécessaire ;
- 50 % n’entre pas dans cette dérogation ;
- multi-employeur, activité indépendante, activité habituelle non-télétravail dans l’État de résidence ou activité dans un troisième État peuvent sortir du champ.

Une valeur fiscale de 40 % ne prouve donc pas l’affiliation sociale, et inversement.

---

## 5. Variables

### 5.1 Minimum canonique FRONT-01

| Variable | Type attendu | Sémantique | Fraîcheur |
|---|---|---|---|
| `residenceCountry` | `CountryCode?` ISO-2 | Pays de résidence déclaré ; pour une conclusion fiscale précise, la résidence conventionnelle doit être confirmée | événement/statique |
| `workCountry` | `CountryCode?` ISO-2 | Pays dans lequel l’emploi est exercé | événement/statique |
| `workCanton` | `SwissCantonCode?` | Canton réel de travail ; obligatoire si `workCountry == CH` | annuelle / changement d’emploi |

Sources admissibles : `userInput`, `certificate`.
Une valeur `estimated` ne sélectionne jamais un régime juridique.

Le permis G peut déclencher une question, mais ne remplit aucun de ces champs.

### 5.2 Minimum supplémentaire avant une orientation fiscale

- année fiscale ou `legalYear` ;
- salarié privé, emploi public, organisation internationale ou autre catégorie ;
- pays d’établissement de l’employeur ;
- confirmation que l’emploi est exercé pour cet employeur ;
- régime de travail annuel complet/partiel ;
- fraction annuelle de télétravail ;
- jours de missions temporaires, ventilés par pays ;
- pour l’accord de 1983 : fréquence de retour et attestation 2041-AS ;
- provenance et dates de chaque fait.

### 5.3 Variables utiles

- salaire brut annuel réel et période ;
- date de début/fin d’emploi ;
- nombre total de jours/heures travaillés ;
- télétravail effectué depuis l’État de résidence ;
- missions dans l’État de résidence et dans des États tiers ;
- état civil fiscal confirmé ;
- revenus professionnels du conjoint ;
- personnes à charge ;
- revenus bruts mondiaux du ménage pour la quasi-résidence ;
- barème de paie réellement appliqué ;
- attestation de retenue à la source ;
- dernière décision fiscale, sous forme de référence opaque ;
- attestation A1 et période couverte ;
- nombre d’employeurs et pays de chacun.

### 5.4 Specialist-only

État `specialist-only` si notamment :

- double résidence ou résidence conventionnelle contestable ;
- emploi public, diplomatique ou dans une organisation internationale ;
- administrateur, artiste, sportif ou indépendant ;
- plusieurs employeurs ou activité dans un troisième État ;
- télétravail supérieur à 40 % ;
- missions complexes ou jours non documentés ;
- conditions du statut 1983 incertaines ;
- absence ou incohérence de 2041-AS ;
- application d’une TOU ou quasi-résidence incertaine ;
- conflit entre fiscalité, sécurité sociale et assurance maladie ;
- correction rétroactive ou double imposition non résolue.

---

## 6. États de donnée

| État | Définition | Comportement |
|---|---|---|
| `known` | Valeur canonique explicite, provenance admise, marqueur `userProvidedFields` et timestamp | Peut sélectionner un instrument, sans suffire à calculer l’impôt |
| `missing` | Valeur absente ou sans preuve canonique | État partiel, résultat masqué, question ciblée |
| `estimated` | Déduction système, valeur d’exemple ou héritage ambigu | Libellé « à confirmer », ne sélectionne aucun instrument |
| `stale` | Fait présent mais sous le seuil de fraîcheur | Afficher l’ancienne valeur et demander une reconfirmation en un geste |
| `specialist-only` | Juridictions connues mais situation hors classification déterministe sûre | Résumé des faits et questions, aucun résultat fiscal |

Predicate minimal :

```text
jurisdictionReady =
  residenceCountry != null
  && workCountry != null
  && (workCountry != CH || workCanton != null)
  && allRequiredFactsAreKnownAndFresh
```

`crossBorder` ne peut être évalué qu’après cette readiness :

```text
crossBorder = jurisdictionReady
              && residenceCountry != workCountry
```

---

## 7. Fixtures officielles

### 7.1 Résident suisse

```yaml
residenceCountry: CH
workCountry: CH
workCanton: GE
```

Attendu :

- état `known`;
- `crossBorder == false`;
- aucune activation du parcours frontalier ;
- aucun accord de 1983 ;
- aucun résultat d’impôt à la source frontalier ;
- aucun régime de télétravail transfrontalier ;
- orientation vers le parcours fiscal domestique si nécessaire.

### 7.2 Résident français travaillant à Genève

```yaml
residenceCountry: FR
workCountry: CH
workCanton: GE
```

Attendu :

- juridiction complète ;
- `crossBorder == true`;
- `candidateTaxInstrument == cdi1966Article17`;
- `accord1983Applies == false`;
- texte éducatif « imposition suisse/à la source possible selon les faits » ;
- aucun taux et aucun montant tant que les entrées du barème officiel ne sont pas complètes ;
- aucun barème C déduit de « marié » seul ;
- télétravail et assurances sociales affichés comme deux contrôles séparés.

### 7.3 Juridiction manquante

Exemple :

```yaml
residenceCountry: FR
workCountry: CH
workCanton: null
```

Attendu :

- état `missing`;
- `jurisdictionReady == false`;
- `crossBorder` non conclu ;
- aucun instrument sélectionné ;
- aucun calcul fiscal ou social ;
- aucune substitution `GE`, `CH` ou `France` ;
- question : « Dans quel canton travailles-tu principalement ? »

Le même comportement doit être prouvé pour chacun des trois champs manquants.

---

## 8. Matrice déterministe de tests

| ID | Entrées | Résultat attendu |
|---|---|---|
| FRONT-D01 | CH / CH / GE | domestique, non frontalier |
| FRONT-D02 | FR / CH / GE | CDI 1966, accord 1983 exclu |
| FRONT-D03 | FR / CH / VD + conditions 1983 absentes | instrument 1983 candidat, conclusion fiscale interdite |
| FRONT-D04 | FR / CH / VD + conditions 1983 confirmées | orientation « imposition de résidence selon accord 1983 », aucun montant |
| FRONT-D05 | `residenceCountry=null` | partial, ask résidence, aucun défaut |
| FRONT-D06 | `workCountry=null` | partial, ask pays de travail |
| FRONT-D07 | FR / CH / `workCanton=null` | partial, ask canton de travail |
| FRONT-D08 | permis G mais juridictions nulles | toujours partial |
| FRONT-D09 | canton de résidence GE mais canton de travail absent | aucune copie vers `workCanton` |
| FRONT-D10 | résidence FR estimée, CH/GE connus | aucune sélection d’instrument |
| FRONT-D11 | FR/CH/GE, fait juridiction périmé | reconfirmation, résultat masqué |
| FRONT-D12 | FR/CH/GE, télétravail absent | orientation fiscale de base seulement |
| FRONT-D13 | année 2026, taux télétravail 39,9 % | dans la limite fiscale de 40 %, si toutes les autres conditions sont remplies |
| FRONT-D14 | année 2026, taux télétravail 40,0 % | limite incluse |
| FRONT-D15 | année 2026, taux télétravail 40,1 % | règles ordinaires art. 17 dès le premier jour ; `specialist-only` |
| FRONT-D16 | `homeOfficeDays=90` sans temps annuel | aucune conclusion |
| FRONT-D17 | social 24,9 %, relation admissible | procédure sociale ordinaire, séparée du fiscal |
| FRONT-D18 | social 25–49,9 %, relation admissible sans A1 | maintien non confirmé, demander A1 |
| FRONT-D19 | social 25–49,9 % avec A1 valide | couverture affichée comme fait documentaire |
| FRONT-D20 | social 50 % | accord-cadre dérogatoire non applicable |
| FRONT-D21 | marié, revenus conjoint inconnus | barème C non conclu |
| FRONT-D22 | salaire seul, aucune table officielle annuelle | aucun calcul de retenue |
| FRONT-D23 | emploi public/international/multi-État | `specialist-only` |
| FRONT-D24 | sérialisation/restart des trois faits | mêmes valeurs, sources et timestamps après redémarrage |
| FRONT-D25 | modification du canton de résidence | ne modifie jamais le canton de travail |

Aucun test ne doit figer les montants actuellement produits par `sourceTaxRates`. Cela testerait une approximation juridiquement non fondée.

---

## 9. Texte éducatif conforme

### Juridiction manquante

> « Ta résidence, ton pays de travail et ton canton de travail peuvent conduire à des règles fiscales différentes. Il manque encore une juridiction pour identifier le cadre pertinent. Aucun montant n’est calculé tant que ce fait n’est pas confirmé. »

### Genève

> « Genève ne fait pas partie des huit cantons couverts par l’accord frontalier de 1983. Pour un emploi salarié privé, la convention franco-suisse et les règles genevoises orientent généralement le salaire vers une imposition en Suisse. Les caractéristiques de ton emploi, de ton ménage et du télétravail restent à confirmer. »

### Cantons de l’accord de 1983

> « Dans huit cantons, l’accord franco-suisse de 1983 peut attribuer l’imposition du salaire à l’État de résidence lorsque ses conditions sont remplies. La fréquence des retours, l’attestation de résidence et la nature de l’emploi doivent encore être vérifiées. »

### Télétravail

> « La règle fiscale franco-suisse actuelle raisonne en pourcentage du temps de travail annuel. Dans son champ, elle prévoit une limite de 40 %. Les assurances sociales suivent un cadre distinct, avec leurs propres conditions et une attestation A1. »

### Disclaimer

> « Les résultats présentés sont des estimations à titre indicatif, basées sur les données fournies et la législation en vigueur. Ils ne constituent pas un conseil financier personnalisé. Consulte un·e spécialiste pour ta situation spécifique. »

---

## 10. Handoff spécialiste

Questions à inclure :

1. Quel État te considère comme résident fiscal pour l’année concernée ?
2. Ton emploi est-il privé, public, international ou indépendant ?
3. Dans quel pays et, en Suisse, dans quel canton travailles-tu effectivement ?
4. Où ton employeur est-il établi ?
5. Combien d’employeurs as-tu et dans quels pays ?
6. Quel est ton temps de travail annuel contractuel et effectivement réalisé ?
7. Quelle fraction est télétravaillée depuis ton État de résidence ?
8. Combien de jours de mission ont été réalisés dans l’État de résidence et dans des États tiers ?
9. Pour l’accord de 1983, disposes-tu de l’attestation 2041-AS et combien de nuits ne rentres-tu pas dans l’État de résidence ?
10. Quel barème de retenue figure sur la fiche de salaire ?
11. Les revenus mondiaux du ménage ont-ils été documentés pour l’éventuelle quasi-résidence ?
12. Une attestation A1 existe-t-elle et quelle période couvre-t-elle ?
13. Une décision fiscale ou une correction est-elle déjà intervenue en Suisse ou en France ?
14. Existe-t-il un risque de double imposition ou une divergence entre administrations ?

---

## 11. Section dossier/PDF

Titre :

> **Fiscalité transfrontalière — faits et points à confirmer**

Contenu minimal :

- date de génération et `legalYear` ;
- résidence déclarée, pays et canton de travail ;
- source, date et état de fraîcheur de chaque juridiction ;
- instrument identifié et raison du routage ;
- mention explicite si l’accord de 1983 est seulement candidat ;
- nature d’emploi ;
- temps annuel, télétravail et missions ventilés ;
- statut 2041-AS ;
- référence opaque de décision fiscale ;
- référence opaque de l’attestation A1 ;
- faits manquants/périmés ;
- liste des questions pour le ou la spécialiste ;
- sources officielles datées ;
- disclaimer.

Le PDF ne doit contenir par défaut ni copie de document, ni numéro fiscal, ni numéro AVS, ni adresse exacte, ni identité complète de l’employeur.

---

## 12. Limites nLPD/FADP

Les juridictions, le salaire, le ménage, les jours de présence et les documents fiscaux permettent d’évaluer la situation économique, la localisation et les déplacements. Leur combinaison peut constituer un profilage à risque élevé.

Contraintes :

1. **Minimisation**
   - pays et canton suffisent au routage initial ;
   - ne pas collecter d’adresse exacte, GPS ou journal quotidien de déplacements ;
   - conserver des agrégats annuels plutôt qu’un calendrier détaillé.

2. **Finalité**
   - les faits sont collectés pour l’orientation éducative et le dossier choisi ;
   - aucune réutilisation pour marketing, scoring ou ciblage.

3. **Exactitude**
   - conserver source, `sourceDate`, `updatedAt` et `legalYear` ;
   - rendre la correction et la reconfirmation possibles.

4. **Sécurité**
   - stockage local chiffré conforme au contrat MINT ;
   - aucune valeur personnelle dans logs, analytics, captures ou audits ;
   - références documentaires opaques, sans document brut.

5. **Handoff**
   - consentement explicite et spécifique ;
   - destinataire nommé ;
   - aperçu et possibilité de retirer des sections ;
   - durée de conservation annoncée ;
   - suppression et révocation accessibles.

6. **Transfert international**
   - informer sur l’État destinataire et les garanties ;
   - vérifier LPD art. 16–19 avant tout transfert hors appareil.

7. **AIPD**
   - requise avant traitement à grande échelle, profilage à risque élevé ou centralisation de ces données.

8. **France/RGPD**
   - une résidence française ne suffit pas, à elle seule, à trancher l’applicabilité territoriale du RGPD ;
   - le produit doit néanmoins appliquer par défaut les garanties les plus protectrices sans transformer ce champ en avis juridique.

Les obligations nominatives d’échange prévues par l’art. 28ter concernent les employeurs et autorités. Elles ne justifient pas que MINT collecte le numéro fiscal, l’adresse complète ou l’identité employeur.

---

## 13. Conditions avant RED/code

`mint-mobile` peut écrire le RED FRONT-01 seulement après archivage de ce verdict.

Le RED doit prouver :

- absence actuelle des trois faits typés ;
- absence de readiness fail-closed ;
- reconstruction et sérialisation manquantes ;
- permis G insuffisant ;
- impossibilité de distinguer CH/CH/GE de FR/CH/GE ;
- aucun défaut vers GE/CH/France.

Le scope FRONT-01 peut ajouter les faits canoniques et le predicate. Il ne doit pas « réparer » les calculateurs actuels avec de nouvelles approximations.

Tant qu’un chantier fiscal séparé n’apporte pas les tables officielles annuelles, les variables complètes et les preuves métier :

- masquer les montants fiscaux ;
- masquer la comparaison classée des charges ;
- supprimer la jauge de 90 jours ;
- conserver uniquement une orientation éducative et les questions de collecte.

## Key Learnings:

1. Genève relève de la convention fiscale générale, pas de l’accord frontalier de 1983.
2. Le télétravail fiscal franco-suisse est borné à 40 % du temps annuel, sans seuil universel de 90 jours.
3. Le seuil social inférieur à 50 % et l’attestation A1 sont indépendants du régime fiscal.
4. Un permis G ne suffit jamais à sélectionner un instrument fiscal.

---

# G1-RET-REF-01 — Verdict Swiss-domain sur les références spécialistes

**Date de vérification :** 2026-07-17
**Rôle :** `mint-swiss-brain`
**Périmètre :** références LPP, pilier 3a et décision fiscale ; orientation
éducative uniquement

## 14. Verdict

| Contrat | Verdict |
|---|---|
| Une signification précise exige une référence opaque, datée et rattachée à l'année juridique pertinente | **PASS requis** |
| Un nom de fichier, un contenu OCR, un `updatedAt` global ou l'année courante par défaut qualifie la preuve | **NO-GO** |
| Un délai générique de demande de capital LPP est déduit de la loi | **NO-GO** |
| Une référence incomplète, périmée ou conflictuelle conserve une sortie précise | **NO-GO** |
| L'absence de preuve conserve une explication générale et une question pour la caisse, le prestataire ou l'autorité | **PASS requis** |

RET-REF-01 peut rendre une référence **connue**, jamais le document brut ni
une conclusion personnelle. La référence ne devient utilisable que si son
tuple complet est valide au `asOf` explicite du calcul ou de l'écran.

## 15. Sources officielles et portée

| Source primaire | État vérifié | Conséquence produit |
|---|---|---|
| [OFAS — Prévoyance vieillesse dans la prévoyance professionnelle](https://www.bsv.admin.ch/fr/prevoyance-vieillesse-prevoyance-professionnelle) | Consultée le 2026-07-17 | Le délai de demande d'une prestation en capital est celui fixé par l'institution de prévoyance. MINT ne possède donc aucun délai universel. |
| [OFAS — Le troisième pilier](https://www.bsv.admin.ch/fr/le-troisieme-pilier) | Publiée le 2026-02-10, consultée le 2026-07-17 | L'ordre des bénéficiaires 3a relève de l'OPP 3 et de la désignation admissible ; un résumé personnel exige la clause et l'année juridique. |
| [Conseil fédéral/OFAS — Adaptations OPP 2 et OPP 3](https://www.bsv.admin.ch/fr/newnsb/fFBgrSAIiYiGRg9YfWRfM) | Publiées le 2026-06-12 ; modification 3a annoncée pour le 2027-06-01 | Une clause 3a sans `legalYear` peut changer de sens entre 2026 et 2027 ; l'année ne peut pas être implicite. |
| [AFC — Formulaires et instructions IFD](https://www.estv.admin.ch/fr/formulaires-et-instructions-impot-federal-direct) | Consultée le 2026-07-17 | Les autorités cantonales sont responsables de la taxation ordinaire ; une référence fiscale doit conserver période et juridiction, pas seulement « dernière taxation ». |
| [AFC — Impôt fédéral direct](https://www.estv.admin.ch/fr/impot-federal-direct) | Consultée le 2026-07-17 | Les factures provisoires et définitives ne sont pas interchangeables ; la référence ne promeut jamais une estimation en décision. |

## 16. Type commun et frontière BND-05

Le modèle cible est un **value object de référence spécialiste**, sans document :

```text
SpecialistReferenceEvidence
  referenceId   opaque UUIDv4 déjà créé par le pont documentaire
  kind          enum fermé du présent contrat
  ownerKind     self ou propriétaire pseudonyme explicite
  source        certificate uniquement
  sourceDate    date civile du document ou de la décision
  legalYear     année dont les règles donnent le sens
  confirmedAt   instant UTC de confirmation dans MINT
```

`referenceId` réutilise l'identité opaque produite par BND-05. En revanche,
`CoachProfile` ne doit pas importer `providers/document_provider.dart` :
`ConfirmedDocumentReference` est aujourd'hui limité à `kind=lpp`, à un
`snapshotId` LPP et à l'autorité du provider. Le writer adapte cette liaison
vers le value object du modèle ; il ne duplique ni fichier, ni OCR, ni valeur
financière. Un simple UUID non résolu par l'autorité BND-05 ne suffit pas à une
écriture de production.

Clés interdites dans ce value object : `filename`, `path`, `bytes`, `ocrText`,
`sourceText`, numéro fiscal, numéro AVS, valeur financière ou copie du document.

## 17. Les quatre faits canoniques

| Champ | `kind` | Complément obligatoire | Fraîcheur/invalidation | Sortie autorisée quand complet |
|---|---|---|---|---|
| `lppRegulationReference` | `lppRegulation` | tuple commun complet + liaison d'autorité courante | persiste jusqu'au changement de caisse/plan ou au remplacement du règlement ; aucun TTL au 1er janvier | « règlement identifié pour l'année juridique indiquée », sans interpréter une option |
| `lppCapitalNoticeDeadline` | `lppCapitalNotice` | tuple commun + `deadlineDate` explicite lue dans ce règlement/avis | délai échu ou avis/règlement/caisse remplacé ; aucun TTL annuel distinct de la date | date citée comme exigence de la caisse, jamais comme délai légal suisse |
| `pillar3aBeneficiaryClause` | `pillar3aBeneficiaryClause` | tuple commun + prestataire/contrat lié par référence opaque | contrat, désignation, prestataire ou situation familiale modifié, ou règle juridique effectivement entrée en vigueur | ordre/clause « selon le document confirmé », sans conseil successoral |
| `latestTaxDecisionReference` | `taxAssessmentDecision` | tuple commun + `referenceId == TaxSnapshot.snapshotId` + `taxYear`, `jurisdiction` et `subject` cohérents | décision rectifiée, annulée ou remplacée, ou identité/contexte du `TaxSnapshot` divergent ; aucun TTL annuel | décision de base identifiée, sans calcul ni extension à une autre période |

Pour `lppCapitalNoticeDeadline`, `deadlineDate` est une donnée du document de
la caisse. La loi et l'OFAS n'autorisent pas MINT à remplacer cette donnée par
« trois mois », « six mois » ou toute autre constante.

`legalYear` est la provenance/version juridique sous laquelle le fait est lu ;
ce n'est jamais un TTL comparé automatiquement à `asOf.year`, ni l'année de
`confirmedAt`. Pour une décision de taxation portant sur 2025 et émise en
2026, `legalYear = taxYear = 2025`, tandis que `sourceDate` porte la date 2026
de la décision. `sourceDate` et `confirmedAt` doivent être non futurs. Une date
source absente, un owner absent, une source autre que `certificate`, un `kind`
divergent ou un identifiant non canonique ferme le prédicat de précision.

## 18. États et prédicats fail-closed

| État | Définition | Comportement MINT |
|---|---|---|
| `known` | tuple complet, autorité opaque courante résolue, dates non futures, owner/kind cohérents et aucun événement invalidant connu | exposer le fait référencé et ses limites |
| `missing` | champ ou élément du tuple absent | explication générale + question ciblée |
| `stale` | liaison de caisse/plan/règlement remplacée, délai échu, contrat/désignation/prestataire/famille modifié, règle effectivement entrée en vigueur ou décision fiscale remplacée | montrer l'ancienne référence, demander confirmation, masquer la précision |
| `conflict` | deux autorités actuelles et divergentes pour le même owner/kind/période | aucune sélection par `updatedAt` ou UUID ; demander arbitrage |
| `invalid` | source, date, ID, owner, kind ou payload non conforme | rejeter sans hydratation partielle |

Les quatre prédicats de précision sont indépendants. Une référence LPP valide
ne complète ni la clause 3a ni la décision fiscale. Le résultat global demeure
`educationalOnly` tant que la référence exigée par la phrase précise n'est pas
`known`. Aucune référence ne rend un montant, un taux ou une recommandation
« vérifié » à elle seule.

Une reconfirmation annuelle peut exister comme politique UX de fraîcheur, mais
elle doit être portée par son propre contrat et ses propres dates. Elle ne peut
pas être déduite de l'inégalité entre `legalYear` et l'année civile de `asOf`.

## 19. Fixtures synthétiques RED → GREEN

| ID | Fixture | Attendu |
|---|---|---|
| RETREF-D01 | quatre champs absents | quatre prédicats faux ; éducatif uniquement |
| RETREF-D02 | `filename=reglement.pdf` sans UUID/source/date/année | rejet ; aucun fait connu |
| RETREF-D03 | UUID valide + `updatedAt`, sans `sourceDate` | faux |
| RETREF-D04 | tuple complet mais `source=userInput` | faux |
| RETREF-D05 | tuple complet avec date future | faux |
| RETREF-D06 | règlement LPP complet, `legalYear=2026`, owner self, même autorité évaluée en 2027 sans remplacement | règlement connu ; le changement d'année seul ne le périme pas et les trois autres restent faux |
| RETREF-D07 | `deadlineDate` seule ou délai constant du code | faux |
| RETREF-D08 | avis/règlement complet avec délai explicite de caisse | délai connu et attribué à la caisse |
| RETREF-D09 | clause 3a complète, puis contrat/désignation/prestataire/famille modifié ou règle différente effectivement entrée en vigueur, notamment au 1er juin 2027 | stale ; aucune conclusion bénéficiaire ; le seul passage au 1er janvier ne suffit pas |
| RETREF-D10 | clause 3a complète, contrat courant et aucun événement invalidant connu, évaluée après un simple changement d'année civile | référence connue selon le document confirmé, sans recommandation ni conclusion successorale |
| RETREF-D11 | décision fiscale complète mais UUID, période, juridiction ou subject divergent du `TaxSnapshot` exact | conflict ou missing, jamais sélection silencieuse |
| RETREF-D12 | décision 2025 définitive, `inForce` et attestée, émise en 2026, avec `legalYear=taxYear=2025`, `sourceDate` en 2026 et `referenceId == snapshotId` exact | référence connue même après changement d'année civile, aucun taux inventé |
| RETREF-D13 | sérialisation puis reconstruction des quatre références | mêmes tuples et mêmes états |
| RETREF-D14 | payload JSON contenant contenu OCR ou chemin local | rejet du payload entier |
| RETREF-D15 | deux références divergentes de même rang | conflict ; l'UUID ou `updatedAt` ne départage pas |

Le RED exact doit atteindre ces prédicats métier dans le vrai modèle. Une
absence de fichier de test, une erreur d'import ou un parseur qui ne compile
pas ne constitue pas un RED acceptable.

## 20. Frontière no-advice et handoff

MINT peut dire :

- « Le règlement confirmé pour 2026 contient une échéance au 30 septembre ;
  vérifie-la avec ta caisse » ;
- « Cette clause 3a est celle du document confirmé pour l'année applicable » ;
- « Cette décision fiscale concerne la période et la juridiction indiquées ».

MINT ne peut pas dire :

- « la loi impose toujours ce délai » ;
- « choisis le capital avant cette date » ;
- « cette personne héritera » sans vérifier la clause et le droit applicable ;
- « cette décision prouve ton taux futur » ;
- « l'option est meilleure, optimale ou fiscalement recommandée ».

Le handoff spécialiste transmet seulement les références opaques, périodes,
owners, états de fraîcheur, hypothèses et questions ouvertes. Tout export du
document brut exige un autre consentement, un autre contrat de minimisation et
une preuve de destinataire ; RET-REF-01 ne l'autorise pas.

## 21. Addendum d'arbitrage de fraîcheur — 2026-07-17

Cet addendum remplace la formulation « annuelle » des anciennes tables et la
fixture qui assimilait tout passage de 2026 à 2027 à une péremption. `asOf`
reste requis pour rejeter une source ou une confirmation future et pour
constater l'échéance explicite d'un avis ; il ne transforme jamais
`legalYear` en date d'expiration calendaire.

La modification OPP 3 annoncée pour le 1er juin 2027 confirme cette frontière :
un millésime ne distingue pas les règles applicables avant et après une entrée
en vigueur intra-annuelle. Le writer ou le consumer doit donc apporter
l'événement d'autorité pertinent — remplacement caisse/plan/règlement,
contrat/désignation/prestataire/famille modifié, nouvelle règle entrée en
vigueur ou décision fiscale remplacée — et retomber sur `educationalOnly` si
ce contexte manque ou diverge.

Pour la fiscalité, la référence réutilise exactement l'UUID du `TaxSnapshot`
autorisé. Elle n'est `known` que pour un `assessmentNotice` `inForce`, attesté,
avec `sourceDate`, `taxYear`, canton et subject complets et cohérents. Une
décision concernant 2025 conserve `legalYear=2025` même si sa date de décision
est en 2026 ; elle ne devient pas périmée au 1er janvier suivant.

## Key Learnings RET-REF-01

1. Le délai de demande du capital LPP est fixé par l'institution de prévoyance ; MINT ne doit jamais en inventer un universel.
2. La modification OPP 3 annoncée pour le 1er juin 2027 rend `legalYear` indispensable comme provenance, mais insuffisant comme TTL ; l'entrée en vigueur effective doit piloter l'invalidation.
3. Une référence opaque prouve une liaison documentaire, pas la vérité d'un montant, d'un taux ou d'un conseil.
4. Les quatre références restent indépendantes et toute précision manquante, périmée ou conflictuelle retombe sur `educationalOnly`.

---

# G1-SUCCESSION-01 — Verdict Swiss-domain sur le régime et les instruments

**Date de vérification :** 2026-07-19
**Rôle :** `mint-swiss-brain`
**Périmètre :** faits de régime matrimonial, testament, pacte successoral,
mandat pour cause d'inaptitude et directives anticipées ; aucune nouvelle
calculatrice, route ou recommandation successorale

## 22. Verdict

| Contrat | Verdict |
|---|---|
| Le mariage, le partenariat, le concubinage, les enfants ou le ménage permettent d'affirmer le régime effectivement applicable | **NO-GO** |
| L'absence d'une référence prouve l'absence d'un testament, pacte, mandat ou directives | **NO-GO** |
| Des faits explicitement confirmés, typés, datés et sérialisés autorisent une préparation spécialiste bornée | **PASS requis** |
| Une situation incomplète conserve les instruments `unknown` et une sortie éducative sans montant personnel | **PASS requis** |

`G1-SUCCESSION-01` est actuellement **NO-GO** :
`estate_reference_contract_test.dart` et les champs canoniques n'existent pas.
De plus, le live `/succession` dérive un `FamilyStatus` de l'état civil puis
affiche un scénario « Avec testament » visuellement favorisé, une part de 50 %
et un taux concubin de 24 %. Ajouter seulement des champs au modèle laisserait
donc un consumer contraire au fail-closed et au no-advice.

## 23. Sources officielles et portée au 2026-07-19

| Source primaire | État vérifié | Conséquence produit |
|---|---|---|
| [Fedlex — Code civil suisse, RS 210, état 01.01.2026](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/24/233_245_233/20260101/fr/pdf-a/fedlex-data-admin-ch-eli-cc-24-233_245_233-20260101-fr-pdf-a.pdf) | art. 181, 196, 470 à 472 vérifiés le 2026-07-19 | Le régime ordinaire est la participation aux acquêts, mais un contrat ou un régime extraordinaire peut s'appliquer ; la liquidation réelle n'est donc jamais déduite du seul mariage. |
| [OFJ — entrée en vigueur de la révision successorale](https://www.bj.admin.ch/fr/nsb?id=83570) | Révision entrée en vigueur le 01.01.2023 | Ne jamais réintroduire les fractions antérieures à 2023. |
| [OFJ — dossier Droit successoral](https://www.bj.admin.ch/fr/droit-successoral) | Consulté le 2026-07-19 | Toute précision future doit rester liée à la version Fedlex applicable. |

Depuis 2023, les héritiers réservataires de l'art. 470 CC sont les descendants,
le conjoint et le partenaire enregistré survivants. L'art. 471 fixe leur
réserve à la moitié du droit successoral légal ; les père et mère n'ont plus de
réserve. L'art. 472 ajoute une frontière en cas de procédure de divorce. Ces
règles autorisent une explication générale, pas une distribution personnelle :
il faut encore connaître notamment le régime et sa liquidation, les héritiers,
les dispositions pour cause de mort, les libéralités pertinentes et, dans un
cas transfrontalier, le droit applicable.

## 24. Modèle minimal et invariants

```text
MatrimonialRegimeKind? matrimonialRegime
  participationInAcquests | communityOfProperty |
  separationOfProperty | other

EstateInstrumentReference[] estateInstrumentReferences
  kind: will | inheritancePact | incapacityMandate |
        advanceCareDirective
  referenceId: UUIDv4 opaque
  ownerKind: self
  source: certificate
  sourceDate: date civile
  legalYear: année juridique explicitement confirmée
  confirmedAt: instant UTC canonique
```

- `null` ou liste vide signifie **unknown**, jamais `notApplicable`, « absent »
  ou « aucun testament ».
- `fromWizardAnswers` ne dérive rien de `civilStatus`, `married`, partenaire,
  enfants, canton, objectifs ou anciens booléens `hasWill` / `hasMandate`.
- Un payload peut être écrit uniquement par une clé dédiée explicite et garde
  sa provenance par le writer canonique.
- Un kind dupliqué avec deux tuples divergents produit `conflict`; ni UUID ni
  `updatedAt` ne départage.
- Toute référence incomplète, future, non-certificate ou contenant filename,
  path, bytes, OCR, identité ou contenu est rejetée en bloc.
- Le changement d'état civil ne crée ni ne détruit silencieusement un fait ; il
  invalide la précision jusqu'à confirmation si sa portée a pu changer.

## 25. Fixtures SUCCESSION-01 RED → GREEN

| ID | Fixture | Attendu |
|---|---|---|
| SUCC-D01 | profil par défaut | régime nul, liste vide, readiness faux |
| SUCC-D02 | marié, partenaire et enfants, sans clés dédiées | tous les faits restent unknown |
| SUCC-D03 | célibataire, concubin ou partenariat enregistré, sans références | aucun `notApplicable` ou instrument absent n'est fabriqué |
| SUCC-D04 | anciens booléens `hasWill`, `testamentExists`, `hasPact`, `hasMandate` | ignorés et non resérialisés |
| SUCC-D05 | régime explicite + quatre références complètes | round-trip exact, quatre kinds indépendants |
| SUCC-D06 | tuple privé de UUID, owner, sourceDate, legalYear ou confirmedAt | rejet et educational-only |
| SUCC-D07 | source autre que `certificate` ou date future | invalid, aucune précision |
| SUCC-D08 | filename, path, OCR ou document brut | rejet sans fuite dans `toJson` |
| SUCC-D09 | deux références divergentes du même kind | conflict, aucune sélection silencieuse |
| SUCC-D10 | changement de civilStatus après confirmation | aucun fait inventé ; précision suspendue si portée à reconfirmer |

Le RED doit être sémantique dans le modèle réel. Un fichier absent, une erreur
d'import ou un échec de compilation n'est pas une preuve RED acceptable.

## 26. Frontière no-advice et handoff

MINT peut dire : « Le régime ou le document n'est pas encore confirmé ; voici
les points à vérifier avec un·e notaire ou juriste. » MINT ne peut pas dire
« ce régime s'applique », « cette personne recevra 50 % », « ce testament est
préférable » ou afficher un impôt cantonal personnel depuis un taux générique.

Le handoff minimal contient les états connus/unknown/conflict, références
opaques, dates/années, hypothèses ouvertes et questions sur le régime, les
héritiers, les dispositions, les libéralités et le droit applicable. Il exclut
le document brut, l'identité des bénéficiaires et toute recommandation.

## Key Learnings SUCCESSION-01

1. Le régime ordinaire légal n'est pas une preuve du régime réellement applicable à un couple donné.
2. Une référence absente prouve seulement que MINT ne sait pas, jamais que l'instrument n'existe pas.
3. Les fractions 2023 peuvent soutenir une éducation générale, pas une distribution personnelle sans faits successoraux complets.

---

# G1-AVS-02 — Verdict Swiss-domain sur la 13e rente de vieillesse

**Date de vérification :** 2026-07-19
**Rôle :** `mint-swiss-brain`
**Périmètre :** preuve officielle owner-scoped, cold restart et cash-flows
visibles séparés ; aucun lissage mensuel ni activation implicite

## 27. Verdict

Le noyau `AvsThirteenthPensionCalculator` est déjà substantiellement
implémenté : son test ciblé passe **72/72** sur le checkout audité. Cela ne
ferme pas `G1-AVS-02`.

| Contrat | État actuel |
|---|---|
| Calcul par mois, centimes exacts, droit décembre, exclusions et fail-closed | **Implémenté / test ciblé GREEN** |
| Ingestion et persistance owner-scoped de douze mois + décision décembre | **Manquant** |
| Destruction/reconstruction du provider et preuve cold restart | **Manquant** |
| Rente mensuelle ordinaire, supplément décembre et total annuel rendus sur trois lignes distinctes | **Manquant** |
| Runtime d'activation et consentement | **Manquant ; flag correctement false** |
| Version de règle distinguant date d'effet et état documentaire | **À corriger** |

L'unique bridge produit, dans `IndependantsService`, utilise encore l'owner
générique `independant-self-scenario` et fusionne le supplément dans
`projectionSansLpp` / `projectionAvecLpp` lorsque le flag de test est forcé.
Les fichiers `avs_thirteenth_evidence_restart_test.dart` et
`avs_thirteenth_cashflow_rendering_test.dart` sont absents. L'exact command du
ticket n'a donc pas encore de RED sémantique complet ni de GREEN.

## 28. Sources officielles et snapshot applicable

| Source primaire | État vérifié | Conséquence produit |
|---|---|---|
| [OFAS — C 13 RV, no 318.303.06](https://sozialversicherungen.admin.ch/fr/d/21610/download) | Valable dès le 01.01.2026, **état 17.06.2026**, vérifiée le 2026-07-19 | Source opérationnelle des conditions, mois, arrondis, exclusions, mutations, corrections et cas transitoires. |
| [OFAS — mise en œuvre de la 13e rente AVS](https://www.bsv.admin.ch/fr/misenoeuvre-13-rente-avs) | Publiée le 19.06.2026 | Premier versement décembre 2026 ; aucun montant précis avant décembre ; caisse de décembre compétente. |
| [Fedlex — LAVS art. 34ter, version 01.01.2026](https://www.fedlex.admin.ch/filestore/fedlex.data.admin.ch/eli/cc/63/837_843_843/20260101/fr/pdf-a/fedlex-data-admin-ch-eli-cc-63-837_843_843-20260101-fr-pdf-a.pdf) | En vigueur dès le 01.01.2026 | Base légale du supplément annuel. |

`effectiveFrom=2026-01-01` et la version documentaire sont deux faits
différents. Le token actuel `OFAS-C13RV-2026-01-01` ne prouve pas que le
snapshot **état 17.06.2026** est celui qui a été appliqué, notamment pour le
chapitre 12 précisé en juin. Le contrat doit conserver un identifiant tel que
`C13RV-318.303.06-state-2026-06-17` en plus de l'année légale.

## 29. Règles gelées

1. Le droit naît seulement si la personne est en vie le 1er décembre et a
   droit à une rente de vieillesse AVS en décembre.
2. Pour chaque mois, la part vaut 8,3333 % de la rente de vieillesse
   déterminante effectivement versée, arrondie aux centimes ; la somme est
   arrondie commercialement au franc au paiement.
3. Sont incluses les rentes vieillesse ordinaires/extraordinaires, déjà
   plafonnées, réduites pour anticipation, augmentées après ajournement et avec
   supplément de veuvage lorsque la caisse les classe ainsi.
4. Sont exclues les rentes AI/survivants/enfants, la rente complémentaire, le
   supplément AVS 21 et les prestations inconnues. Une composante inconnue
   bloque la certification.
5. Le couple est calculé séparément pour chaque owner après plafonnement des
   rentes mensuelles ; aucun second plafond n'est appliqué au supplément.
6. Avant décembre ou sans preuve de la caisse compétente, seul un scénario
   éducatif daté est possible. Une déclaration documentée ne devient pas une
   décision de caisse.
7. Un décès ou une extinction du droit avant le 1er décembre produit zéro
   sourcé sans prorata. Un décès en décembre laisse la rente de décembre et le
   supplément dus comme prestations en cours.
8. La rente mensuelle ordinaire reste inchangée ; le supplément n'est jamais
   lissé par `13/12` ni absorbé dans un revenu récurrent.

## 30. Fixtures AVS-02 RED → GREEN complémentaires

Les 72 cas du noyau sont conservés. Les RED manquants doivent atteindre les
vrais writer, reload et renderer :

| ID | Fixture | Attendu |
|---|---|---|
| AVS13-I01 | douze mois et décision décembre officiels, owner self, centimes exacts | save-before-publish puis cold reload identique |
| AVS13-I02 | données partner mélangées au root self | rejet owner mismatch ; aucun total ménage |
| AVS13-I03 | référence/sourceDate/version d'un mois absente | `sourceTooWeak`, aucun montant certifié |
| AVS13-I04 | snapshot effectif 01.01.2026 mais état de circulaire antérieur au 17.06.2026 pour un cas chap. 12 | version non qualifiée, partial+ask |
| AVS13-I05 | décision décembre `unknown` avant décembre | `pendingDecember`, estimation éducative datée seulement |
| AVS13-I06 | restart après persistance officielle complète | mêmes owners, mois, exclusions, source dates et décision ; aucun double |
| AVS13-I07 | écran avec preuve certifiée | trois lignes distinctes : rente ordinaire mensuelle, supplément décembre, total annuel |
| AVS13-I08 | écran pending/declared/scenario | aucune ligne libellée certifiée ; hypothèses/source visibles |
| AVS13-I09 | AI, survivant, enfant, complémentaire et AVS 21 | cash-flows exclus visibles séparément, jamais ajoutés au supplément |
| AVS13-I10 | flag false après preuve et restart | aucune surface activée ; activation nécessite une décision et un runtime distincts |

## 31. Frontière no-advice, consentement et confidentialité

Le produit peut expliquer la règle, afficher un montant fourni/certifié par la
caisse avec sa date, ou une estimation explicitement éducative. Il ne peut pas
promettre le versement, appeler un scénario « ton montant », lisser le
supplément dans le budget mensuel, ni choisir entre rente de vieillesse et rente
de survivant. La caisse rend la décision et traite contestations/corrections.

Le root persistant conserve un owner pseudonyme, des montants mensuels exacts,
la classification, les références opaques et les dates. Il ne conserve ni
numéro AVS, ni identité de caisse en clair, ni document brut. L'ingestion et un
handoff éventuel exigent consentement explicite, finalité annoncée, aperçu et
suppression. Les logs, audits et captures restent synthétiques et sans PII.

Le flag `enableAvsThirteenthScenarioCashflow` reste false jusqu'à la preuve
writer → process death → cold reader, au rendu séparé, au runtime exact-SHA et
aux audits wrapper code/product-domain sans P0/P1.

## Key Learnings AVS-02

1. Un noyau de calcul 72/72 ne prouve ni l'autorité persistée ni le rendu produit.
2. La date d'effet 01.01.2026 ne remplace pas la version de circulaire état 17.06.2026.
3. Le supplément de décembre est un cash-flow séparé, jamais un treizième mois récurrent lissé.
