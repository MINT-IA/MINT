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
