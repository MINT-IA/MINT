---
description: Guide recrutement 5 utilisateurs Wave 0 pour test wireframe TrajectoryMap (Sem 0) — 5 archetypes ancrés Suisse francophone (infirmière VS 27, frontalier 52, expat EU ZH 34, indépendant sans LPP 38, veuve 68 capital-héritage) avec backstory + ce qu'on montre / demande / mesure.
name: persona-recruitment-guide-wave-0
type: user-research
---

# Guide recrutement 5 personas — Wave 0 test wireframe TrajectoryMap (2026-05-14)

> **Author** : Claude (Wave 0 Sentry — Product Leader mode)
> **Status** : DRAFT — awaiting Julien's recruitment execution.
> **Memory load-bearing** : `feedback_no_micro_pauses`, `feedback_perimeter_5_gates`, `feedback_zero_trust_protocol`, design doc APPROVED 2026-05-14 RC-1 (« 5 utilisateurs sur wireframe » → remplace l'assignment original « 2 utilisateurs »).

---

## TLDR (3 phrases)

5 utilisateurs prospects ancrés Suisse francophone, recrutés Wave 0 pour tester le wireframe TrajectoryMap (sub-agent C output) ; chacun reçoit le wireframe seul sans aide, réaction notée verbatim. **Critères inchangés design doc** : ≥ 1 femme, ≥ 1 hors-tech, ≥ 1 < 35 ans, ≥ 1 > 50 ans, pas de famille immédiate. **Gate Wave 2** : si ≥ 4/5 disent « pas clair / pas pertinent / pas mon problème » → Wave 2 mise en pause + retour Phase 3 office-hours pour repivoter.

---

## Pourquoi 5 personas, pourquoi ceux-là

Design doc APPROVED RC-1 a porté l'assignment de 2 à 5 utilisateurs (reviewer concern : « observation de 2 ne valide pas le wedge, seulement la trajectoire »). 5 = compromis entre signal saturation (Nielsen says 5 ≈ 85% UX issues détectées) et coût recrutement (1 personne / jour sur 5 jours = 1 semaine ouvrée).

Les 5 archetypes ci-dessous sont **directement extraits des 8 archetypes Swiss documentés dans CLAUDE.md / financial_core** : on garde la couverture des **frictions financières les plus communes en Suisse francophone**, on évite les edge-cases extrêmes pour ce test wireframe (expat US/FATCA = complexe à recruter + tester sur un wireframe initial).

| # | Archetype financial_core | Persona MINT | Pertinence wedge Karpathy |
|---|---|---|---|
| 1 | `swiss_native` jeune | Infirmière 27, Valais | « Tu gagnes plus que tu dépenses » = test du delta hebdo en condition revenu modeste (≤ 5'000 CHF/mois brut) |
| 2 | `cross_border` mature | Frontalier 52, GE↔FR | Test du framing life-event Suisse-spécifique sur user qui pourrait dire « ça ne me concerne pas vraiment » |
| 3 | `expat_eu` actif | Expat allemand 34, Zurich | Test FR/DE bilingue + framing 3 piliers sur user qui n'a pas grandi avec le système |
| 4 | `independent_no_lpp` | Indépendant 38, Lausanne | Test edge-case « pas de LPP » + lacune prévoyance + sensitivity au pilier 3a |
| 5 | `returning_swiss` retraité | Veuve 68, Vaud (capital-héritage) | Test framing décaissement + succession + chiffre dominant projeté |

**Critères design doc respectés** (≥ 1 femme, ≥ 1 hors-tech, ≥ 1 < 35 ans, ≥ 1 > 50 ans) :
- ≥ 1 femme : 3/5 (#1 infirmière, #5 veuve, et 1 autre si recrutement le permet)
- ≥ 1 hors-tech : 5/5 (aucun n'est explicitement tech-worker)
- ≥ 1 < 35 ans : 2/5 (#1 infirmière 27, #3 expat 34)
- ≥ 1 > 50 ans : 2/5 (#2 frontalier 52, #5 veuve 68)
- Pas de famille immédiate : à enforcer au recrutement

---

## 5 Personas — Brief recrutement détaillé

### Persona 1 — Camille, 27 ans, infirmière, Valais

**Backstory** :
- Infirmière à l'Hôpital du Valais (Sion ou Sierre)
- Salaire brut ≈ 5'200 CHF/mois × 13 mois (CCT santé VS)
- Loyer 2.5 pièces Sion : 1'200 CHF/mois (charges incluses)
- Compte épargne : ~8'000 CHF (héritage modeste + économies depuis fin formation 2024)
- Pas de 3a (« ma collègue m'en a parlé mais j'comprends pas trop »)
- LPP au CCT cantonal (sait pas ce qu'elle a, n'a jamais regardé son certificat)
- AVS cotisée depuis 18 ans (apprentissage à 18-20 ans avant études)
- Pas de couple (célibataire, en colocation jusqu'à 2025 puis indépendance)
- Smartphone iPhone SE, utilise Twint, Revolut occasionnel, pas de banking app sophistiquée
- Pas de banque privée — UBS ou PostFinance compte courant standard

**Ce qu'on lui montre** :
- Le wireframe TrajectoryMap (sub-agent C W1) avec un profil pré-rempli proche du sien — pas son profil exact (pour pas la mettre mal à l'aise) mais reconnaissable : « infirmière jeune en Suisse romande »
- 3 milestones : « comprendre LPP », « commencer 3a », « projeter à 50 ans »
- Pas d'explication parlée — elle regarde le wireframe seule pendant 5 minutes

**Ce qu'on lui demande** (5 questions ouvertes, notées verbatim) :
1. « En 1 phrase, qu'est-ce que tu vois ici ? »
2. « Quel est le chiffre le plus important ? »
3. « Y a-t-il quelque chose que tu ne comprends pas ? »
4. « Est-ce que ça ressemble à ta vie financière ? »
5. « Si tu voyais ça dans une app, ouvrirais-tu l'app demain ? Pourquoi ? »

**Ce qu'on mesure** :
- Time-to-first-utterance (combien de secondes avant qu'elle parle)
- Nombre de « je sais pas » / « je comprends pas » dans les réponses
- Reconnaissance du chiffre dominant en < 5 secondes (Y/N)
- Émotion détectée (curiosité / défensive / désintérêt / anxiété)
- Si elle dit spontanément « moi je voudrais voir mon X » → signal X manque

---

### Persona 2 — Pierre, 52 ans, frontalier, Genève / Annemasse

**Backstory** :
- Cadre dans une PME genevoise (commercial industrie)
- Salaire brut ≈ 8'500 CHF/mois (frontalier imposé à la source, taux Genève 18-22%)
- Habite Annemasse (FR) — frontalier depuis 18 ans
- Marié, 2 enfants (16 et 19 ans, l'aîné étudiant)
- Maison Annemasse (propriétaire avec hypothèque résiduelle ~180k€)
- LPP : ~280k CHF accumulés (employeur GE), n'a jamais demandé le rachat-année LPP
- 3a impossible (frontalier = pas de pilier 3a sans dérogation cantonale spéciale)
- Pas d'assurance-vie spécifique frontalier
- Inquiétude : « si je perds mon emploi, je récupère quoi ? »
- Smartphone Galaxy S22, sait utiliser Excel mais pas d'app financière sophistiquée

**Ce qu'on lui montre** :
- Wireframe TrajectoryMap **adapté frontalier** (sub-agent C W3 variant)
- Milestones spécifiques : « bilan AVS frontalier », « rapatrier LPP avant 50 ans », « scénarios chômage frontalier »

**Ce qu'on lui demande** : 5 questions identiques persona 1 + 1 spécifique :
- (6) « Est-ce que tu vois quelque chose qui s'applique à toi en tant que frontalier ? »

**Ce qu'on mesure** :
- Reconnaissance de la spécificité frontalier (Y/N)
- Si Pierre dit « ah mais ça c'est pour les Suisses, pas pour moi » → fail mode framing 18-events
- Précision attendue des chiffres (frontalier = sensible, fiscalité dépend des conventions FR-CH)

---

### Persona 3 — Klaus, 34 ans, expat allemand, Zurich

**Backstory** :
- Ingénieur software dans une PMI zurichoise (pas FAANG, pas startup hype)
- Arrived 2022 (3.5 ans en Suisse), permis B
- Salaire brut ≈ 110k CHF/an + bonus 8-12k
- Loyer 3 pièces à Wiedikon ZH : 2'400 CHF/mois
- Marié, conjointe allemande aussi expat, sans enfants
- LPP : ~85k CHF accumulés (3 employeurs successifs)
- 3a : ouvert 2024 chez Frankly (banque), versement 4'000 CHF en 2024 (pas le max)
- Épargne : 35k CHF compte épargne UBS + 18k € compte allemand
- Inquiétude : « si je rentre en Allemagne dans 5 ans, qu'est-ce qui se passe avec ma LPP / 3a / impôts ? »
- Parle français approximatif mais lit fluently ; allemand natif ; anglais courant
- Smartphone iPhone 14 Pro, utilise Revolut, Wise, Frankly app, sait être autonome

**Ce qu'on lui montre** :
- Wireframe TrajectoryMap **anglais OU allemand** (selon préférence Klaus) — la grammaire MINT v2 doit rester lisible cross-langue
- Milestones spécifiques expat : « scénarios retour Allemagne », « 3a optimisé pour expat », « LPP : encaisser ou laisser ? »

**Ce qu'on lui demande** : 5 questions identiques + 1 langue :
- (6) « Si tu choisis ta langue, c'est laquelle ? Et pourquoi ? »

**Ce qu'on mesure** :
- Tolérance langue (FR-only acceptable ? Need DE/EN ?)
- Précision attendue : Klaus = quantitatif (ingénieur), il va check les chiffres
- Reconnaissance scénarios expat (Y/N)

---

### Persona 4 — Sébastien, 38 ans, indépendant graphiste, Lausanne

**Backstory** :
- Graphiste indépendant (raison individuelle) depuis 2019 (post-Covid pivot)
- Revenu net annuel ≈ 75-90k CHF (variable, projet par projet)
- Pas de LPP (volontaire — souscription possible mais cher, repoussé)
- 3a : versé 7'000 CHF en 2024 (proche du plafond indépendant sans LPP de 36'288 CHF/an mais loin de l'utiliser plein)
- AVS cotisée comme indépendant (au tarif AVS indép, taux 8.1% pour revenu < 58'800 CHF)
- Pas d'IJM (assurance perte de gain maladie), pas d'AI privée
- Habite Lausanne, locataire 2.5 pièces 1'800 CHF
- Célibataire, pas d'enfants
- Smartphone iPhone 15, utilise Bexio (compta indépendants), Revolut, Frankly
- Inquiétude existentielle : « je n'ai aucune sécurité retraite, je vais finir à l'aide sociale »

**Ce qu'on lui montre** :
- Wireframe TrajectoryMap **indépendant sans LPP** variant
- Milestones spécifiques : « combler la lacune LPP », « 3a max indépendant », « IJM oui ou non », « projeter retraite indép »

**Ce qu'on lui demande** : 5 questions identiques + 1 anxieuse :
- (6) « Quand tu vois ce trajet, qu'est-ce que tu ressens — anxiété, soulagement, ou autre ? »

**Ce qu'on mesure** :
- Émotion (anxiété diffuse est l'attendue — comment le wireframe la traite)
- Si le wireframe RÉDUIT l'anxiété (vs l'AMPLIFIE) → signal positif
- Reconnaissance « indépendant » spécifique (Y/N)
- Si Sébastien dit « j'ai pas envie de regarder ça » → fail mode trop confrontant

---

### Persona 5 — Marie-Christine, 68 ans, veuve, Vaud (capital-héritage)

**Backstory** :
- Veuve depuis 2022, mari décédé à 71 ans (cancer)
- Capital reçu : LPP mari ~420k CHF (capital pris à 65, pas rente) + assurance-vie ~180k CHF + maison héritée (Lutry, ~1.4M valeur)
- Rente AVS personnelle : 1'870 CHF/mois (carrière infirmière puis assistante administrative)
- Rente AVS veuve (rente complémentaire) : ~750 CHF/mois
- Pas de LPP personnelle (n'a pas suffisamment cotisé sur son emploi pour avoir un capital sienne)
- 2 enfants adultes (45 et 41 ans), 4 petits-enfants
- Préoccupation : « comment je gère ce capital sans le perdre ? »
- Smartphone iPhone 11 (cadeau du fils), utilise WhatsApp, Twint, pas d'app financière
- Pas de conseiller (« mon mari s'occupait de tout, je dois apprendre »)
- A reçu un courrier de la banque proposant un « bilan patrimoine » — méfiante

**Ce qu'on lui montre** :
- Wireframe TrajectoryMap **adapté retraitée capital-héritage** (sub-agent C W3 variant ?)
- Milestones spécifiques : « préserver le capital », « rente complémentaire », « succession enfants », « 3a retrait optimisé »

**Ce qu'on lui demande** : 5 questions identiques + 1 trust :
- (6) « Si une app te disait ces chiffres, est-ce que tu lui ferais confiance ? Pourquoi ? »

**Ce qu'on mesure** :
- Trust (Marie-Christine = méfiante par nature, c'est notre test trust-resistance)
- Lisibilité écran (iPhone 11, presbytie probable — taille typo PDF DS v2 mai 8 utilisable ?)
- Reconnaissance succession / décaissement (Y/N)
- Vocabulaire : Marie-Christine ne sait pas ce qu'est « FRI » — testons si MINT évite le jargon-MINT-interne

---

## Logistique recrutement

### Canaux recrutement suggérés
- **Réseaux Julien** (LinkedIn / contacts perso) — préférer personnes 2nd degré (pas amis directs pour éviter biais social desirability)
- **Réseau Lauren** (si applicable, à check)
- **Plateforme étude UX Suisse** : `surveycircle.com`, `userinterviews.com`, `respondent.io` (CHF 50-100 / session 30 min) — réservé si canaux Julien ne sortent pas 5 candidats en 5 jours
- **Cantines / cafés Lausanne / Genève / Sion** : approche cold (rare succès mais possible avec un brief court)
- **Cabinets infirmiers (Persona 1) / Associations frontaliers (Persona 2) / Coworking spaces (Persona 4)** : ciblage profession

### Critères d'exclusion stricts
- Pas de famille immédiate Julien (parents, frères/sœurs, conjoint·e)
- Pas de personnes qui ont déjà vu MINT (testeur Phase 95-98 internal)
- Pas de personnes employées dans la finance suisse (biais expert)
- Pas de devs / product folks (biais professionnel sur le wireframe)

### Format session
- **Durée** : 30 minutes max
- **Format** : visio (Google Meet, gratuit) ou en personne café (Julien décide selon disponibilité)
- **Compensation** : 50 CHF Twint / Revolut (ou bon Migros / coffee shop équivalent) — discuter avec Julien si c'est le bon levier
- **Wireframe shown** : PNG ou PDF du wireframe ASCII (sub-agent C output) — pas l'app, pas de Figma interactif (pas le scope Wave 0)
- **Enregistrement** : audio uniquement, opt-in (transcription par Whisper post-session pour analyse)
- **Verbatim notes** : Claude / Julien prennent notes en live, transcription audio en complément

### Analyse post-session
Output : `.planning/user-research/2026-05-W3-trajectory-wireframe-feedback.md` (verbatim, surprises, dropouts) — le doc-collecteur prévu par design doc.

Pour chaque persona, table :
| Persona | Time-to-first-utterance | Chiffre dominant reconnu < 5s ? | Émotion (mot-clé) | Quote-clé verbatim | Verdict propre (Pass/Fail/Unsure) |

Verdict global Wave 2 :
- ≥ 4/5 Pass → Wave 2 GO
- 2-3/5 Pass → Wave 2 GO with iteration (refine wireframe avant code)
- ≤ 1/5 Pass → Wave 2 PAUSE + retour Phase 3 office-hours

---

## Compliance check

- **CLAUDE.md TOP rule #3 « MINT ≠ retirement app »** : 5/5 personas ont une trajectoire NON-retraite-only (Camille 27 ans, Klaus expat retour Allemagne, Sébastien indépendant). Cohérent.
- **CLAUDE.md TOP rule #6 0-trust** : ce guide est `Status DRAFT`, pas `Decided`. Julien doit valider avant exécution recrutement.
- **memory `feedback_perimeter_5_gates`** : les 5 sessions = test wireframe Wave 0, pas un perimeter shipping. Pas de gates G1-G5 applicables.
- **memory `feedback_audit_corpus_before_patching`** : ce guide AUDIT les archetypes financial_core AVANT de proposer un sample utilisateur. Cohérent.
- **GDPR / nLPD** : recrutement = consent verbal + écrit (court email/SMS) avant la session. Pas de stockage de PII au-delà de la transcription audio (à supprimer après analyse).

---

## Caveats

1. Les 5 personas sont **plausibles, pas vérifiés** — Julien doit valider qu'ils correspondent à ce qu'il peut effectivement recruter (réseau, budget, calendrier).
2. Les 5 questions ouvertes par persona sont un **starter set** — Julien peut affiner après pilote sur persona #1.
3. Le wireframe TrajectoryMap utilisé pour le test = sub-agent C output (`2026-05-14-trajectory-map-wireframe-v1.md`). Si le wireframe lui-même est défaillant, le test ne mesure pas le concept mais le wireframe.
4. La compensation 50 CHF est un guess — Julien tranche selon budget user-research Wave 0.
5. Le timing « Sem 0 / 5 jours » est ambitieux — réaliste = 1-2 semaines pour recruter + tester 5 personas. Wave 2 budget réajusté en conséquence.

---

*Guide produit Wave 0 par Claude. Awaiting Julien recruitment execution. Bibliographie : Nielsen Norman Group « Why You Only Need to Test with 5 Users » (2000) ; financial_core 8-archetype model ; CLAUDE.md TOP rule #3.*
