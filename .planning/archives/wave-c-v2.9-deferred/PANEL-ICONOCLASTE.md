# Panel Iconoclaste — Wave C Scan Handoff

**Date** : 2026-04-18
**Composition** : designer principal d'Arc Browser, product lead Things 3, founder fintech boutique suisse (VZ Finanzplanung era)
**Mission** : challenger la PRÉMISSE de Wave C, pas polir l'exécution
**Durée** : 45 min, review complète du PLAN v1

---

## Verdict global : **CHALLENGE PRÉMISSE — pivot majeur requis sur C1, C2, C4. C3 OK. C5 OK mais ADR insuffisant.**

Wave C dans sa forme actuelle est une honnête itération câblage. Mais trois des cinq commits reproduisent des patterns Cleo/Duolingo que la doctrine MINT (chat-silent + no-cliché + lucidité) exige de refuser. L'équipe exécute ce qui "semble évident" (post-scan → handoff coach → chips life events → skip landing) alors que chaque "évidence" est un chemin déjà battu par les apps que MINT refuse d'être. Le panel recommande un pivot avant EXECUTE, pas un rework après.

Le diagnostic central : **Wave C confond "câbler ce qui existe" avec "câbler ce qui mérite d'exister".** Il y a une différence entre combler une façade et se demander si la façade devait être là.

---

## C1 — Post-scan auto-handoff coach

### Cliché détecté : **OUI, majeur.**

Le pattern "scan → CTA 'En parler à Mint' → opener contextuel 'On a lu ton certificat CPE. Voici ce que ça change pour toi.'" est le trope **Cleo "we noticed something"** version suisse. C'est le même mouvement que Duolingo's "Time to practice!", Monzo's "We spotted a trend", Klarna's "Smart tip for you". C'est ce que toute app qui se croit intelligente fait dès qu'elle a une info. Et c'est précisément ce que la doctrine `feedback_chat_must_be_silent.md` refuse : **silence > annonce**.

Le PLAN écrit "opener contextuel remplace silent opener générique". C'est l'aveu. On brise la doctrine silence pour un moment où on croit avoir quelque chose à dire. Mais la doctrine n'est pas "silence sauf quand on a une info". C'est "silence, point. Le user demande, MINT répond."

Pire : l'opener proposé est un **énoncé affirmatif au nom de MINT** ("voici ce que ça change pour toi"). C'est du marketing. Un taste-maker ne fait jamais ça. VZ Finanzplanung historique ne dit jamais "voici ce qui change pour toi" — VZ présente un tableau chiffré, l'humain lit, l'humain pose la question, le conseiller répond. Dissymétrie respectée : l'outil ne présume pas que l'humain veut un verdict.

### Ce qu'Arc / Things 3 / VZ feraient à la place

**Arc Browser** : après qu'un utilisateur ait fait une action de captation (bookmark, Space, Easel), Arc ne propose **jamais** de "en parler à l'assistant". L'action est consommée, point. L'info existe silencieusement dans le système. Si l'user veut revenir dessus, il y a un endroit canonique pour la retrouver. **Le handoff n'est pas poussé, il est disponible.**

**Things 3** : quand tu crées une tâche complexe (avec date, project, tag, deadline), Things 3 ne t'ouvre **rien**. Zero modal, zero suggestion, zero "want to chat about this task?". La capture est la fin. Le système attend. Le retour à la tâche vient de l'humain, pas du système.

**VZ Finanzplanung (era 1990-2010)** : quand un client déposait un certificat LPP, le conseiller ne disait pas "voici ce que ça change pour vous". Le conseiller **attendait la question**. Si elle ne venait pas, le conseiller présentait le document annoté et laissait le silence faire le travail. **Le silence après capture = respect de l'intelligence du client.**

### Proposition concrète pour C1

**Ne pas faire le handoff automatique. Faire la capture silencieuse.**

1. Post-scan `document_impact_screen` : garder le récap visuel (chiffres extraits, confiance, champs enrichis). C'est la preuve de travail. C'est suffisant.
2. CTA bas de l'écran : **un seul verbe**, l'action évidente. Pas "En parler à Mint". Pas "Continuer". Juste un tap qui ferme le flow de capture et retourne home.
3. **Pas d'opener contextuel dans le coach.** Le coach reste silencieux. Si l'user ouvre le chat après un scan, la greeting reste "On commence par quoi ?" (ou variante neutre). Le scan enrichit le dossier en arrière-plan ; le coach ne se met pas à "parler du scan" comme un vendeur qui vient de voir entrer son prospect dans la boutique.
4. Ce qui change : le **home** (pas le coach) reflète la nouvelle info. Un tile "ton LPP est passé de 42% à 71% de complétude" apparaît naturellement sur home. Si l'user touche ce tile, **là** on ouvre un contexte coach préchargé. Dissymétrie : l'user **demande** en tappant, MINT ne prend pas la parole en premier.
5. Entry payload `CoachEntryPayload(source: scanResult, ...)` reste utile mais est **consommé seulement si l'user tap un tile home post-scan**, pas automatiquement après close de `document_impact_screen`.

**Référence** : pattern de Stripe Atlas post-incorporation — le dashboard met à jour les chiffres, mais ne fait jamais pop-up "Let's talk about your LLC". Arc Easel après drag. Things 3 après quick-entry.

**Conséquence sur le PLAN** : C1 n'est plus un handoff, c'est une capture silencieuse + home reflection. Ce qui remonte le problème à Wave B (home orchestrateur) qui n'est pas encore shippée. **C1 doit attendre Wave B ou être radicalement re-scoped.**

---

## C2 — Suggestion-chip regex étendu 18 life events

### Cliché détecté : **OUI, structurel.**

Les chips suggérés contextuellement depuis le texte du coach = **le pattern Duolingo/Replika pur**. C'est le rail de rédaction guidée. C'est ce qui transforme une conversation en questionnaire-déguisé-en-chat. L'user croit choisir, mais il choisit dans une liste que le système a pré-rédigée. C'est la version fintech du "Continue" / "Skip" / "Maybe later" de Duolingo.

Le PLAN liste 18 life events, un mapping granulaire (déménagement canton vs déménagement pays, first job vs new job, housing purchase vs housing sale, etc.). C'est une taxonomie backend qui remonte à l'UI. **Les users ne parlent pas en taxonomie.** Un user dit "je déménage" — pas "je déménage canton" ni "je déménage pays". Pousser une chip qui force à choisir entre les deux = imposer la grammaire du backend à l'humain. Inversion de dissymétrie.

Le PLAN note "Panel B a identifié 7 intent tags orphelins". C'est l'alarme : **l'UI a déjà plus de chips que le backend ne sait router**. Ajouter 18 chips sur un système qui n'honore pas 7 tags actuels, c'est empirer la façade.

### Ce qu'Arc / Things 3 / Linear feraient à la place

**Arc Browser** : Arc Max (l'assistant) n'a **pas de chips suggérées**. Tu tapes ta question en langage naturel. Arc Max extrait l'intent côté serveur et répond. La surface utilisateur reste 1 input texte. **Zero prédigestion.**

**Things 3** : le Magic Plus (drag-to-create) n'a pas de chips d'intent. Tu tapes du texte, Things parse naturellement "Friday 3pm" ou "#project". L'intelligence est **dans le parser, pas dans les chips**.

**Linear** : les suggestions de commande (Cmd+K) sont **toutes disponibles en permanence**, pas contextuellement poussées selon ce que Linear "pense que tu veux". Anti-paternalisme.

**ChatGPT (bon contre-exemple récent)** : ils ont tué les "suggested prompts" sur home parce que ça tuait la créativité user et créait du pattern-matching au lieu de pensée. Leur plus grande amélioration UX 2024.

### Proposition concrète pour C2

**Kill les chips contextuels post-coach response. Garder 3 chips émotionnels statiques au cold-start uniquement.**

1. Aligner avec `feedback_chat_must_be_silent.md` : au cold-start de coach, 3 chips émotionnels fixes ("Est-ce que ça va aller pour la retraite ?", "Je paie trop d'impôts, non ?", "Il m'arrive quelque chose"). **Ces 3 chips sont le seul moment où MINT rédige pour l'user.**
2. Après la première réponse user (tap chip ou tape du texte), **plus jamais de chips dynamiques**. L'user parle, MINT parse l'intent côté backend (intent classifier robuste), MINT répond. Si l'intent est orphelin côté backend → MINT dit "Je note, je ne sais pas encore traiter ça directement" (honnêteté) au lieu de faire semblant via une chip qui mène à un dead-end.
3. Le routage vers screens (intent → `/simulateur/lpp`) doit être **déclenché par l'intent détecté dans le texte user**, pas par le texte de la réponse MINT. Asymétrie correcte : user écrit "je voudrais voir mon rachat LPP" → backend détecte `life_event_lpp_rachat` → response inline + éventuel deep-link discret (pas chip poussée).
4. Pour les 18 life events : les implémenter **côté backend parser** (NLU/Claude intent detection), **pas côté UI chips**. Le mapping doit être invisible à l'utilisateur.

**Référence** : Cleo 2020 avait pivoté vers un chat full texte sans chips après avoir vu que les chips tuaient l'engagement long-terme. Cleo 2023 est revenu aux chips pour l'entertainment. MINT ≠ entertainment. **MINT doit prendre la décision Cleo 2020, pas Cleo 2023.**

**Conséquence sur le PLAN** : C2 devient "kill les chips dynamiques, renforcer le parser backend". Le tableau regex → mapping disparaît. Travail plus court côté Flutter, plus long côté backend. **Probablement hors-scope Wave C — à déférer Wave E ou dédiée "parser intent NLU".**

---

## C3 — Memory retry back-off

### Cliché détecté : **NON.**

Robustesse silencieuse, invisible pour l'user, logs debug. C'est exactement ce qu'un bon système fait. Retry + backoff + breadcrumb Sentry = plomberie saine. Pas de surface UI, pas de message "re-trying...", pas de spinner.

**Une seule amélioration marginale** : le PLAN propose 1 retry avec back-off 500ms. Considérer jittered backoff (400-600ms) pour éviter thundering herd si l'erreur est un backend overload. Détail d'ingé, pas un pivot.

### Verdict : **PROCEED AS-IS**, panel n'a rien à ajouter.

---

## C4 — Landing skip si onboarded

### Cliché détecté : **OUI, mais l'inverse : le cliché est la landing elle-même.**

Le PLAN propose de **conditionnellement** sauter la landing. Le panel challenge : **pourquoi existe-t-elle ?**

**Arc Browser** après la 1ère install : tu ouvres, tu es dans un Space vide, tu crées un tab, tu navigues. Il n'y a jamais de "landing page" après la première install. La 1ère fois = onboarding léger. Toutes les fois suivantes = **cold-start direct sur l'état vivant**.

**Things 3** après 1ère install : tu ouvres, tu es dans "Today" (vide au début, puis peuplée). Il n'y a pas de "page d'accueil marketing" qui revient à chaque cold-start.

**Stripe Dashboard** : cold-start = le dashboard. Pas une landing. Le dashboard est lui-même la landing.

**Linear** : cold-start = ta vue active (Inbox, Active, whatever). Pas de wordmark qui revient.

**La landing est un artefact de la peur de 2010-2015** où les apps croyaient devoir se re-présenter à chaque ouverture. C'est mort en UX moderne depuis 2018.

### Ce qu'un taste-maker ferait

**Ne conditionner rien. Tuer la landing récurrente. La landing n'existe QUE lors du premier cold-start. Après ça, jamais.**

- Première install → landing (si landing marketing vaut encore la peine ; à challenger en C5).
- Toutes les installations suivantes → `initialLocation: '/home'` (ou `/coach` selon la vision dossier-first).
- **Pas de "si onboarded", pas de "si profile complet".** La règle est binaire : "as-tu déjà dépassé la landing une fois dans ta vie ?" → persist flag `has_seen_landing: true` → re-cold-starts vont direct home.

Le PLAN propose `isOnboarded` comme condition. C'est trop complexe. Un user peut être "non-onboarded" (triad incomplète) mais avoir déjà vu la landing 40 fois. Re-montrer la landing est un insulte à sa mémoire. **Le flag doit être "has_seen_landing", pas "isOnboarded".**

### Proposition concrète pour C4

1. Nouveau flag persisté (SharedPreferences) : `has_seen_landing` booléen.
2. Router initial : si `has_seen_landing == true` → `/home`. Sinon → `/landing`.
3. Landing CTA tap → set flag true → navigate away.
4. Aucune condition sur onboarded/profile/triad. Indépendant du reste.
5. Tester cold-start avec flag true → va direct home, zero flash landing.

**Référence** : Instagram / Twitter / Arc / Things 3 / Linear — tous ont ce flag. Aucun ne redemande "welcome".

**Conséquence sur le PLAN** : C4 devient plus simple (1 flag au lieu d'une lecture profile provider async) et plus rigoureux doctrine ("une fois vue, jamais re-vue").

---

## C5 — Onboarding minimal questionnaire OR ADR

### Cliché détecté : **OUI, subtil mais réel.**

Le PLAN propose un ADR no-onboarding, doctrine lucidité. **Panel iconoclaste valide la direction mais challenge l'implémentation actuelle.**

Le risque : **le "save_fact silent capture via chat" peut devenir un onboarding déguisé en conversation**. Pattern Replika / character.ai où la première conversation est **en réalité un formulaire de 15 questions** mais déguisé en "hey let me get to know you". L'user croit discuter, il remplit un form. C'est un anti-pattern : la dissimulation n'est pas de la doctrine, c'est du manipulatif.

Si Wave A A2 triad-gate est wired (birthYear + canton + salary avant le 1er premier éclairage), **et que le coach drive la conversation vers ces 3 facts**, alors MINT fait un onboarding caché. Même résultat qu'un wizard, juste plus lent et moins honnête.

### Ce qu'un taste-maker ferait

**Décision binaire à prendre dans l'ADR :**

**Option A — Assume "no onboarding, period".** MINT n'a **pas besoin** de la triad pour opérer. Le coach fonctionne avec 0 info. Le premier éclairage du home peut être éducatif/générique sans être générique-daube (contenu différenciant sur une règle Swiss LPP, pas "bienvenue sur MINT"). Les facts s'accumulent **naturellement via conversations sur événements réels** ("je déménage", "j'ai eu un enfant"), pas via interrogatoire déguisé. Triad est un **objectif**, pas une **gate**.

**Option B — Assume "micro-onboarding honnête, 3 questions explicites, 30 secondes".** 3 questions dans une UI sobre (pas un chat fake). "Quelle année tu es né ? Quel canton ? Revenu brut annuel approximatif ?" 3 inputs. Un CTA "On commence". Plus honnête qu'un chat qui pose les mêmes questions déguisées en "discussion".

**Ce que le panel recommande : Option A.** Raison : cohérence doctrine lucidité. L'user n'est pas interrogé, l'user est accueilli. Le flow est "la première chose que l'user voit est la valeur, pas la demande". VZ Finanzplanung : un client n'est jamais interrogé en entrant en boutique. Il est assis, il boit un café, il parle de sa vie, le conseiller écoute. Les facts émergent du contexte.

**Mais** : l'ADR doit **nommer explicitement le risque "onboarding déguisé"** et **garantir que le coach ne drive PAS la conversation vers la triad**. Le coach répond à ce que l'user apporte. Si l'user pose une question qui nécessite un fact (ex : "combien à la retraite ?"), MINT **admet le manque** ("je n'ai pas ton âge pour calculer") + propose d'ajouter (input explicite, pas déguisé), plutôt que de demander en douce.

### Proposition concrète pour C5

**Renforcer l'ADR avec 4 règles explicites :**

1. **Triad n'est pas un gate.** Ni landing, ni home, ni coach ne bloquent l'user sur "donne-moi tes 3 facts".
2. **Coach ne drive JAMAIS vers la triad.** Pas de "Pour mieux te comprendre, dis-moi ton âge". Le coach répond à la demande user, si un fact manque il l'admet.
3. **Home peut afficher un tile discret "complète ton profil pour premiers chiffres précis"** mais optionnel, dismissable, jamais imposé.
4. **save_fact silent via conversation naturelle** reste le mécanisme — mais seulement si l'user mentionne spontanément un fact. MINT ne fishing pas.

**Référence** : Apple Health — tu peux ouvrir Health sans avoir rempli ton profil. L'app donne ce qu'elle peut. Si tu veux plus, tu complètes. Jamais un prompt "Dis-nous ton âge pour continuer". **Dissymétrie totale respectée.**

**Conséquence sur le PLAN** : ADR C5 reste mais doit inclure ces 4 règles. Panel recommande un review design-critique du prompt coach actuel pour vérifier qu'il ne fait pas déjà fishing déguisé.

---

## Synthèse des pivots recommandés

| Commit | Verdict | Pivot |
|---|---|---|
| C1 | **Cliché Cleo "we noticed"** | Kill handoff auto. Home reflète post-scan. Coach reste silencieux. |
| C2 | **Cliché Duolingo chips** | Kill chips dynamiques. Parser backend. 3 chips cold-start uniquement. |
| C3 | OK | Proceed, jittered backoff marginal. |
| C4 | **Cliché landing récurrente** | Kill re-landing. Flag `has_seen_landing` binaire. |
| C5 | Doctrine OK, impl risquée | ADR enrichi avec 4 règles anti-onboarding-déguisé. |

**Recommandation panel** : Wave C telle que scopée contient **deux pivots fondamentaux (C1, C2) qui débordent Wave C** et posent des questions structurelles (home orchestrateur = Wave B, parser intent = Wave E dédiée). **Ne pas EXECUTE Wave C en l'état**. Re-scope en Wave C-minimal = {C3, C4 simplifié, C5 ADR enrichi}. Renvoyer C1/C2 en review Wave B (home) et Wave E (parser).

---

## Références produits citées

- **Arc Browser** (The Browser Company) — dissymétrie capture / handoff, assistant invisible
- **Things 3** (Cultured Code) — capture est la fin, pas le début d'un flow
- **Linear** — commandes toutes disponibles, jamais poussées
- **Stripe Atlas / Dashboard** — dashboard = landing, pas de pop-ups
- **VZ Finanzplanung (era 1990-2010)** — silence après dépôt de document, dissymétrie respectée
- **Apple Health** — fonctionne sans profil, jamais gate
- **ChatGPT 2024** — suppression des suggested prompts (leçon apprise)
- **Cleo 2020 vs 2023** — MINT doit prendre la décision Cleo 2020 (chat texte), pas Cleo 2023 (retour chips)
- **Duolingo** — pattern de chips à **refuser**, pas imiter
- **Replika / character.ai** — anti-pattern "onboarding déguisé en chat"
- **Aesop** — le site e-commerce Aesop n'a pas de pop-up "we noticed you're browsing", respect user

---

## Question ouverte au fondateur

Une question de taste-maker qui dépasse Wave C : **Est-ce que MINT devrait avoir un écran "coach" du tout, ou est-ce que la conversation devrait être 100% intégrée au home (Cleo 3.0 Insight → Plan → Conversation loop inline)?**

Le panel ne tranche pas ici car hors-scope Wave C, mais note que la **séparation "coach" vs "home"** telle qu'elle existe aujourd'hui est un artefact de l'architecture 2024 MINT. La doctrine dossier-first + Cleo 3.0 architecture de référence suggère qu'à terme, il n'y a pas d'onglet coach — il y a un home vivant avec conversation inline. Wave C en l'état renforce la séparation (post-scan handoff vers coach screen). Pivot long-terme à considérer dans ADR vision V2.
