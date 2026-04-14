# 13 — Audit Non-Standard : 5 Experts Hors-Fintech

> **Date** : 2026-04-11 (soirée)
> **Contexte** : Le fondateur a demandé un audit des 3 livrables (10-MANIFESTO,
> 11-INVENTAIRE, 12-PLAN-EXECUTION) par 5 experts issus de disciplines
> étrangères au fintech, avec une consigne explicite : "pas de réponses
> statistiques, de la créativité et de l'innovation, sortir des sentiers battus."
> **Résultat** : 5 audits complets, ~7'500 mots d'analyse critique, 10 innovations
> proposées, 4 questions existentielles soulevées.

---

## 1. Le panel

| # | Expert | Discipline | Score |
|---|---|---|---|
| 1 | Game Designer (école Jenova Chen / Tynan Sylvester) | Core loops, agency, flow, onboarding | 4/10 |
| 2 | Screenwriter (école Sorkin / Coel / Waller-Bridge) | Protagoniste, antagoniste, character arc, dialogue | 4/10 |
| 3 | Behavioral Economist (école Ariely / McGonigal / Mullainathan) | Commitment devices, defaults, scarcity tax, shame | 4/10 |
| 4 | Sociologist of Money (école Zelizer, Princeton) | Earmarking, relational work, moral economy, couples | 2/10 |
| 5 | Philosopher of Technology (école Illich / Stiegler / Morozov) | Convivialité vs dépendance, pharmakon, solutionism | 4/10 |

**Convergence de score** : 4 experts à 4/10, 1 à 2/10. Tous convergent sur :
l'infrastructure est extraordinaire, quelque chose d'essentiel manque au centre.
Chaque expert a donné un nom différent à ce qui manque.

---

## 2. Ce qui manque — 5 noms pour le même trou

| Expert | Ce qui manque | Sa formulation |
|---|---|---|
| Game designer | **Le core loop** | "MINT est un filing cabinet, pas une boucle. Organisé autour de noms (document, dossier, chat) au lieu de verbes (confronte, reframe, décide)." |
| Screenwriter | **L'intériorité** | "Sarah n'est pas un personnage, c'est un screen flow avec un name tag. Pas de wound, pas de desire, pas de monde social." |
| Behavioral economist | **Les commitment devices** | "MINT produit de l'insight et abandonne l'utilisateur au moment exact où le behavior change devrait avoir lieu. Zero follow-through." |
| Sociologist of money | **Les relations** | "Sarah est Descartes à Sion. Pas de famille, pas d'oncle courtier, pas d'earmarking, pas de couple. L'argent n'est jamais fongible dans la vie réelle." |
| Philosopher of technology | **La politique et la graduation** | "MINT ne se rend jamais inutile, ne politise pas le problème, lock l'utilisateur dans un dossier qu'il ne peut pas emporter." |

**Pattern transverse unique** : les 5 experts disent la même chose sous des formes
différentes — **MINT opère à un niveau d'abstraction trop élevé.** MINT produit de
l'*information* quand le monde a besoin d'un produit qui fabrique de la
*transformation*.

---

## 3. Les 10 innovations proposées (classées par radicalité)

### Tier 1 — Adoptables sans renverser le modèle

**1. Implementation intentions comme primitive Layer 4**
- Source : Behavioral economist (Gollwitzer 1999, d=0.65 meta-analysis)
- Mécanisme : Ajouter WHEN/WHERE/IF-THEN à chaque "question à poser au courtier",
  persister comme `ImplementationIntention`, rappeler via `notification_scheduler_service`.
- Effort : 1-2 jours CC
- **Verdict fondateur : OUI**

**2. Fresh-start anchors (pas de streaks)**
- Source : Behavioral economist (Dai/Milkman/Riis 2014, +25-35% session return)
- Mécanisme : Landmark detector (birthday, month-1, year-start, 1-year-anniversary).
  UN message MINT à ces dates. Utilise `anomaly_detection_service` + `snapshot_service`.
- Effort : 1 jour CC
- **Verdict fondateur : OUI**

**3. Pre-mortem avant chaque décision irréversible**
- Source : Behavioral economist (Klein 2007, Kahneman endorsement)
- Mécanisme : "Imagine qu'on est en 2027 et que cette décision s'est mal passée."
  Free text, stocké en dossier. 100% LSFin-compliant.
- Effort : 1-2 jours CC
- **Verdict fondateur : OUI**

**4. Journal de provenance VIA COACH (pas via form)**
- Source : Sociologist of money (Zelizer, money as memory)
- Mécanisme : Le coach demande en conversation "au fait, ce 3a, c'est qui qui te
  l'a proposé ?" et stocke la réponse. Pas un formulaire.
- Correction du fondateur : le form texte libre est trop lourd pour des flemmards.
  Le coach le fait en conversation.
- Effort : 1 jour CC (coach prompt + memory store, existe déjà)
- **Verdict fondateur : OUI (via coach)**

**5. Mode couple dissymétrique**
- Source : Sociologist of money (Zelizer, relational work + intimate economies)
- Mécanisme : "Ce que je sais de mon conjoint (et ce que je ne sais pas)" —
  questionnaire intime, non-partagé. MINT produit les 5 questions à poser au
  partenaire sans que ça fasse une dispute.
- Effort : 2-3 jours CC
- **Verdict fondateur : OUI, très pertinent**

### Tier 2 — Requiert un redesign partiel mais pas un renversement

**6. L'atome = tension, pas document + One-screen living timeline**
- Source : Game designer
- Mécanisme : Un seul écran comme centre de gravité — timeline de nodes (past
  events earned, present tensions pulsing, future projections ghosted). Tap pour
  reveal. Documents, chat, canvases = façons d'unlock des nodes.
- Correction fondateur : "Fantastique. C'est ce que Cleo fait, il me semble."
- Effort : 1-2 semaines CC (refonte architecturale du home screen)
- **Verdict fondateur : OUI comme direction**

**7. Tagging relationnel (differentiated monies) IMPLICITE via coach**
- Source : Sociologist of money (Zelizer, earmarking)
- Mécanisme : Au lieu d'un UI dédié (trop lourd), le coach détecte les earmarks
  implicitement. Si Sarah dit "ça c'est l'argent de ma grand-mère," le coach le
  note et le respecte dans ses analyses futures. Pas de formulaire.
- Correction fondateur : trop lourd comme feature explicite. Le coach fait du
  listening intelligent via `conversation_memory_service.dart`.
- Effort : 1 jour CC
- **Verdict fondateur : OUI (implicite)**

### Tier 3 — Existentiel : contredit quelque chose de structurel

**8. The Graduation Protocol**
- Source : Philosopher of technology (Illich, convivialité)
- Mécanisme : Après la 3e fois qu'un user engage avec un concept, MINT refuse
  de répondre directement et lance un exercice guidé de 90 secondes. Dashboard
  "Concepts tu maîtrises seul : 7."
- Contradiction : graduated user = churned user = contredit le business model SaaS
- Correction fondateur : "Conceptuellement oui, mais Sarah va avoir plein d'autres
  événements de vie sur lesquels elle aura encore besoin de MINT."
- **Verdict fondateur : DIRECTION LONG-TERME (pas immédiat)**

**9. The Dossier Federation (dossier portable, user-owned)**
- Source : Philosopher of technology (Stiegler, tertiary retention + vendor lock-in)
- Mécanisme : Dossier stocké en format ouvert, signé, portable. MINT tourne
  par-dessus. L'utilisateur peut emporter son dossier chez Caritas, chez un
  conseiller humain, chez un concurrent.
- Correction fondateur : "C'est du génie. Ça pourrait aussi être la base pour
  faire enfin une déclaration d'impôt hyper facilement."
- Contradiction : détruit le moat SaaS
- **Verdict fondateur : OUI comme direction long-terme + base pour impôts**

**10. The Political Pocket (5e couche collective_action)**
- Source : Philosopher of technology (Morozov + Winner, re-politicize)
- Mécanisme : Chaque diagnostic MINT pointe vers 2 actions — la personnelle
  (question au courtier) + la politique collective (lettre FRC, plainte FINMA,
  initiative parlementaire). Partnership FRC/SKS/Caritas.
- Correction fondateur : "C'est énorme. On fait de MINT une arme de destruction
  du système. C'est quelque part là où on devrait aller."
- Contradiction : expose MINT à la retaliation FINMA + industrie
- **Verdict fondateur : OUI comme direction existentielle**

---

## 4. Decisions de reframing prises par le fondateur (2026-04-11 soirée)

### Decision 1 — Lucidité, pas protection
**Avant** : "Mint te dit ce que personne n'a intérêt à te dire." (protection, anxiogène)
**Après** : MINT = outil de **lucidité** qui donne **la paix financière, le contrôle,
la compréhension, zéro effort.** Le framing n'est plus "contre les brokers" mais
"pour l'utilisateur, serein, compétent, en contrôle."

La sociologue avait proposé : "MINT te dit ce que tu as déjà deviné." Le fondateur
s'y est aligné.

### Decision 2 — Pour les gens et contre le système
La direction existentielle est adoptée : MINT éduque ET politise. À long terme,
MINT ne se contente pas d'informer l'individu — MINT agrège la douleur des
utilisateurs en pression collective sur le système (FRC, FINMA, initiatives
parlementaires). Le Political Pocket est une direction validée.

### Decision 3 — Le couple n'est pas un setting
Le couple est un fait anthropologique central, pas une préférence d'interface.
Le mode couple dissymétrique est adopté.

### Decision 4 — L'argent n'est pas fongible
Le tagging relationnel est adopté dans sa forme implicite (coach listening via
`conversation_memory_service`). Le patrimoine total comme concept est remis en
question. MINT doit respecter les distinctions sociales que les gens imposent à
leur argent (l'argent de mamie ≠ le bonus de l'année ≠ le 3a de l'oncle courtier).

### Decision 5 — MINT ne désarme pas la conversation humaine, MINT l'arme
Correction au philosophe : quelqu'un qui comprend enfin son LPP grâce à MINT
va en parler à ses potes. MINT n'absorbe pas les conversations, MINT les arme de
contenu et de lucidité.

### Decision 6 — Les données appartiennent à l'utilisateur
Le Dossier Federation est adopté comme direction long-terme. Toutes les données
doivent appartenir à l'utilisateur et être portables.

### Decision 7 — L'infrastructure n'est PAS à 10/10
Correction aux experts : "on a plein d'erreurs de backend, tout est de surface,
on n'a pas codé les tuyaux." L'app ne fonctionne pas sur un iPhone. Deux erreurs
Sentry bloquent le coach chat (document_embeddings manquant, RAG deps manquantes).
Le diagnostic honnête : **du surface code partout, tuyaux non-connectés.**

### Decision 8 — Les 3a assurance ne sont pas un mauvais produit en soi
Correction à la rhétorique anti-broker : le produit 3a assurance peut convenir
à certains profils (protection + épargne pour une mère avec 3 enfants sans 2e
pilier solide). Le problème est de vendre un produit pour la mauvaise personne,
pas le produit lui-même. MINT doit le dire avec nuance, pas avec populisme.

---

## 5. Les 4 questions existentielles que le panel soulève

### Q1 — Lucidité ou dépendance ? (Illich + Stiegler)
MINT rend-il l'utilisateur plus compétent SANS MINT (convivial) ou plus
dépendant DE MINT (industriel) ? La réponse actuelle est : industriel. Le
Graduation Protocol est la réponse, mais il contredit le business model SaaS.
**Décision : direction long-terme.** L'argument du fondateur est que les
événements de vie sont suffisamment nombreux et espacés (mariage, enfant,
hypothèque, changement de job, retraite, décès, divorce) pour que la
graduation sur un concept ne rende pas MINT inutile — elle rend MINT libre
de se concentrer sur le prochain concept. C'est un argument valide mais à
vérifier empiriquement.

### Q2 — Produit privé ou utilité publique ? (Morozov + Stiegler)
MINT est-elle un SaaS à CHF 15/mois ou un instrument civique ? Le Dossier
Federation et le Political Pocket pointent vers l'utilité publique. Le
business model pointe vers le SaaS. **Décision : SaaS qui tend vers l'utilité
publique.** Le fondateur n'a pas résolu cette tension — il a dit "c'est là où
on devrait aller" pour la direction publique, mais n'a pas renoncé au SaaS.
C'est une tension productive à garder, pas à résoudre maintenant.

### Q3 — Information ou transformation ? (Game designer + Screenwriter + Behavioral economist)
MINT produit-elle de l'information (4 layers de texte) ou de la transformation
(comportement changé, compétence acquise, décision prise) ? Les 3 experts
convergent : information aujourd'hui, transformation nécessaire. Les commitment
devices (implementation intentions, pre-mortem, fresh-start anchors) sont
le pont entre les deux. **Décision : intégrer les commitment devices dans
le sprint.** Le core loop / living timeline est le pont architectural.
**Décision : direction moyen-terme.**

### Q4 — Qui est Sarah ? (Screenwriter + Sociologist)
Sarah est-elle un profil fiscal ou une personne ? Les 2 experts convergent :
profil fiscal. Le fondateur a dit "l'exemple de l'infirmière est tellement
juste." **Décision : réécrire Sarah comme une personne avec un monde social.**
Cela affecte le copy, le ton, le coach — pas l'architecture immédiate.

---

## 6. Ce qui est réglé et ce qui ne l'est pas

### Réglé (vision)
- MINT = lucidité, paix, contrôle, zéro effort
- Direction existentielle = pour les gens, contre le système
- Dossier Federation = direction long-terme
- Mode couple dissymétrique = oui
- 5 innovations tier 1 = adoptées
- 2 innovations tier 2 = direction
- 3 innovations tier 3 = direction long-terme

### PAS réglé (le mur)
- L'app ne fonctionne pas sur un iPhone
- 2 erreurs Sentry bloquent le coach chat en staging
- La navigation est grotesque, la boucle cassée, les tuyaux pas connectés
- Aucun utilisateur externe n'a jamais utilisé MINT
- Le sprint de code n'a pas démarré

### Le verdict final
Les 5 audits ont produit la meilleure clarification de vision de MINT depuis
sa création. Le fondateur sait maintenant exactement quel MINT il veut
construire. Mais aucun document de vision ne répare 2 erreurs Sentry ni une
navigation cassée. **Le prochain acte est du code, pas de la stratégie.**

---

*Fin de l'audit. Prochain document : pas un document. Du code.*
*Workflow : GSD (Get Shit Done).*
