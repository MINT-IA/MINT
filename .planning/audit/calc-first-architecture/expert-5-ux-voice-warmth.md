---
description: UX/voice expert read-only research — comment garder la chaleur narrative MINT quand l'architecture passe à « calc deterministe = vérité, LLM = narrateur ». Cite Cleo, Wealthsimple, Monarch (Berman), Copilot, NN/g. Trois propositions concrètes pour la roadmap, contre-argument inclus (warmth qui dérive en patronage / retour au framing « protection »).
---

# Expert 5 — UX / voice / warmth (read-only research)

> **Statut** : recherche, pas décision. Read-only.
> **Date** : 2026-05-09.
> **Prompt** : Stage 3 narrator eval failed (Haiku 5/50, Sonnet 21/50) → pivot architectural « LLM = narrateur sur calc engine ». Risque : MINT sonne comme Excel-with-voiceover.
> **Périmètre** : VOICE_SYSTEM, DESIGN_SYSTEM, copy patterns, comportementaux. **Hors périmètre** : tuning du LLM, scoring du calc engine, tests Stage 3.
> **Contraintes** : MINT ≠ retraite-first ; LSFin (pas de « garanti / optimal / meilleur ») ; accents FR.

---

## 0. Cadrage du risque

Le pivot Stage 3 dit : « le calc engine porte la vérité ; le LLM ne fait qu'illuminer ». Lu naïvement, cela mène à un produit où :

- chaque écran est un chiffre + une phrase générée à la volée,
- la voix MINT (calme/précis/fin/rassurant/net — VOICE_SYSTEM §1) devient un vernis sur des outputs,
- la promesse « ami cultivé qui travaille dans la finance suisse » s'aplatit en TTS/voix off d'un calculateur.

C'est le piège « Excel-with-voiceover ». Les fintechs qui ont ce problème (la plupart des dashboards US) sont ce que Berman appelle des *passive dashboards* : on ouvre, on regarde, on referme, rien n'a bougé dans la tête de l'utilisateur. ([kristenberman.substack.com](https://kristenberman.substack.com/p/monarch-how-a-behavioral-scientist))

À l'opposé : Cleo. Ses utilisateurs interagissent **20× plus souvent qu'avec une banking app standard** parce que la personnalité est un dispositif d'engagement, pas un wrap autour des chiffres. ([techintelpro.com](https://techintelpro.com/news/finance/financial-services/cleo-30-launches-as-ai-financial-coach-with-voice-and-memory))

Il y a donc deux formes possibles de calc-first :

| Forme | Effet | Exemple analogue |
|-------|-------|------------------|
| **Calculator-with-voiceover** (à éviter) | LLM génère des phrases plates autour d'un chiffre. Le chiffre porte la valeur. L'app est un PDF interactif. | la plupart des outils RH/retraite suisses |
| **Calculator-as-stage** (cible) | Le chiffre est une *conséquence* qui se vit dans une scène. La narration n'explique pas le chiffre, elle l'incarne dans l'événement de vie. | Cleo (drama), Wealthsimple (clarté humaine), Monarch (rituel des moments-argent) |

Le pivot Stage 3 ne décide pas entre les deux. C'est cette recherche qui aligne l'UX/voice sur la 2e forme.

---

## 1. Question 1 — Si le LLM est réduit à « illumination », quels UX moves préviennent l'effet Excel-with-voiceover ?

Synthèse de Cleo, Wealthsimple, Monarch (Berman), Copilot Money, plus le pattern *narrative visualization* (Stanford Segel & Heer, Bach et al.). Cinq familles concrètes, classées du plus structurel au plus tactique.

### 1.1 Ambient narration — le chiffre n'arrive jamais nu

Le chiffre est toujours posé dans une **scène déjà composée**. Pas « 63% — c'est ton taux de remplacement », mais : on entre sur un écran qui *est* la conséquence du 63%. Mécaniquement :

- l'écran est cadré par un événement de vie (« Tu changes de job » / « Tu emménages avec ton/ta partenaire »), pas par un calcul.
- le chiffre apparaît **après** l'établissement de l'enjeu (DESIGN_SYSTEM §6.6 règle 1 : *l'écran commence par un enjeu, jamais par un contrôle*).
- la « narration » du LLM ne réintroduit PAS le chiffre. Elle introduit la *question que ce chiffre soulève*.

Référence : pattern *narrative visualization* documenté par Stanford ([vis.stanford.edu](http://vis.stanford.edu/files/2010-Narrative-InfoVis.pdf)) — les meilleures *data stories* établissent un cadre avant la donnée, pas l'inverse. Le chiffre est la **chute**, pas la prémisse.

**MINT impact** : déplace le LLM de « commenter le chiffre » à « cadrer l'événement de vie qui rend ce chiffre saillant ». Le calc engine reste vérité. Le LLM devient *régisseur de scène*, pas voix off.

### 1.2 Micro-stories par data point — le « pourquoi » avant le « quoi »

Berman (Monarch) : remplacer les insights abstraits par des « headline-with-action » : *« Money comes in the 22nd, leaves the 30th for rent »* + une action immédiate. ([kristenberman.substack.com](https://kristenberman.substack.com/p/monarch-how-a-behavioral-scientist))

C'est exactement le pattern « data-backed micro-narrative » documenté en CHI 2025 ([dl.acm.org](https://dl.acm.org/doi/10.1145/3706598.3713999)) : une vignette courte, lue en 4 secondes, qui *humanise* la donnée en l'ancrant dans le quotidien.

Pour MINT, ça veut dire que chaque output deterministe du calc engine se présente avec une **sleeve narrative locale** :

```
[chiffre]  ←  posé par le calc engine, immutable
[1 phrase] ←  posée par le LLM (« régisseur »), 8-15 mots,
              ne reformule PAS le chiffre — elle cadre l'écart
              entre la situation présente et l'événement de vie
```

VOICE_SYSTEM §5 a déjà ce pattern (« chiffre-choc caption »). Le pivot calc-first devrait *systématiser* ce template comme contrat formel entre les deux couches.

### 1.3 Life-event framing — le hub n'est pas « tableaux », c'est « moments »

Cleo et Wealthsimple opèrent le même move : **les écrans sont organisés par moment de vie, pas par produit financier**. ([medium.com](https://medium.com/@prabhjotbains96_67515/i-reverse-engineered-a-style-guide-for-wealthsimple-heres-what-i-learned-7e5dd5948049)) Cleo l'incarne avec « Roast Mode » / « Hype Mode » — modes émotionnels qui correspondent à des moments, pas à des features. ([webpronews.com](https://www.webpronews.com/uk-fintech-cleo-unveils-ai-financial-coach-with-voice-and-memory-boost/))

MINT a déjà la *grammaire* (DESIGN_SYSTEM §2 catégorie C, 18 life events, VOICE_SYSTEM §2 axe 1 « contexte émotionnel »). Le risque calc-first : que ces life events deviennent juste des entrées dans un menu de calculatrices. Ce qu'il faut tenir : **chaque life event est une scène avec son ton, son rythme, son rapport au chiffre**.

Concrètement, le LLM-narrateur a *18 voix tonales fines* (pas 18 voix distinctes — règle anti-caricature VOICE_SYSTEM §3 — mais 18 modulations du même ton de base). Le calc engine ne sait pas que « divorce » mérite une narration plus posée que « job comparison ». Le LLM si.

### 1.4 Archetype-aware metaphors — la règle du local

Le coach MINT a déjà une couche d'identité régionale (VOICE_SYSTEM §9bis : VD/GE/VS/ZH/BE/TI). Ce qui manque côté calc-first, c'est un **dictionnaire de métaphores ancrées par archetype** que le LLM peut piocher pour traduire un chiffre brut en image vécue.

Exemple : le chiffre « 4'200 CHF/mois après retraite » devient, selon l'archetype :

- VS / pré-retraite : *« un 2 pièces à Sion, pas la maison »* (déjà présent §11.1 niveau 3)
- expat US / 35 ans / Genève : *« le loyer aux Eaux-Vives, sans les charges »*
- jeune actif / Vaud : *« un demi-loyer à Lausanne »*

Le calc engine produit le chiffre. Le LLM choisit la métaphore depuis un dico (canton × literacy × event), avec règle anti-caricature (1 marqueur régional par réponse max — §11.3). C'est ce qui empêche le calc d'être nu.

NN/g sur les calculatrices fintech ([nngroup.com](https://www.nngroup.com/articles/calculator-expectations/)) confirme : les calculatrices à fort engagement traduisent toujours le résultat en *unité signifiante pour l'utilisateur* (jours de salaire, mois de loyer, années de café), pas en chiffre brut.

### 1.5 Behavioral hooks — célébrer les moments-argent

Berman, encore : *celebratory alerts on paycheck arrival → 80%+ open rate*. ([kristenberman.substack.com](https://kristenberman.substack.com/p/monarch-how-a-behavioral-scientist)) C'est *exactement* le pattern « milestones / achievements » de VOICE_SYSTEM §5 (« 7 jours de suite. Le rythme est bon. »).

Risque calc-first : ces moments deviennent des *events* émis par le calc engine et templatés sans saveur. Mitigation : les milestones restent **scriptés** côté LLM/copy (pas générés à chaque fois), avec variation contrôlée. Sobre, jamais excessif. Pas d'emoji-spam.

C'est aussi le seul endroit où le contre-argument §6 (warmth → patronage) peut mordre vite : un milestone qui célèbre un dépôt de 50 CHF en pilier 3a peut sonner condescendant si la phrase est mal calibrée. Tester contre VOICE_SYSTEM §4 « DON'T jamais d'exclamation enthousiaste ».

---

## 2. Question 2 — Top référence pour « warm-but-rigorous » fintech narration

**Réponse principale** : Kristen Berman, *« Monarch: How a behavioral scientist would design a fintech app »*, Substack 2024.
URL : <https://kristenberman.substack.com/p/monarch-how-a-behavioral-scientist>

**Takeaway en 1 ligne** : *Ne pas afficher des chiffres — déclencher des « money moments » (paycheck arrival, weekly review, single-merchant question) où chaque insight est une headline en langue naturelle immédiatement suivie d'une action concrète et atomique.*

C'est le seul article qui *montre* mécaniquement comment la rigueur (calc deterministe sur transactions) et la chaleur (alertes émotionnelles, micro-commitments) coexistent sans que l'une efface l'autre.

**Référence secondaire** (méthodologique, plus académique) : Bach et al., *Narrative Design Patterns for Data-Driven Storytelling* ([datavis2020.github.io](https://datavis2020.github.io/pdfs/Narrative_Design_Patterns__for_Data_Driven_Storytelling.pdf)) — 18 patterns documentés, applicables 1:1 à un narrateur LLM qui sleeve un calc engine.

**Référence tertiaire** (pour le ton, pas pour la mécanique) : Wealthsimple culture manual + style guide reverse-engineered ([medium.com](https://medium.com/@prabhjotbains96_67515/i-reverse-engineered-a-style-guide-for-wealthsimple-heres-what-i-learned-7e5dd5948049), [wealthsimple.com/culture](https://www.wealthsimple.com/en-ca/culture)) — démontre qu'on peut garder de la chaleur sans humour bruyant, en jouant sur la *clarté radicale + concrètes du quotidien*. C'est la boussole de ton la plus proche de ce que MINT vise (l'inverse de Cleo, qui est trop bruyant pour la Romandie — VOICE_SYSTEM §1 « ce que MINT n'est pas »).

---

## 3. Question 3 — 3 UX moves concrets pour les 6 prochaines semaines

Trois moves de complexité croissante. Les trois sont compatibles avec le pivot calc-first et tiennent les 6 piliers CLAUDE.md (LSFin, accents, life-event-equal, financial_core, i18n, 0-trust).

### 3.1 Move A — Contrat formel « calc → narrateur » : la *narrative sleeve*

**Quoi** : poser dans le repo (probablement `lib/services/voice/` ou `apps/mobile/lib/services/narrator/`) un type `NarrativeSleeve` qui formalise ce que le LLM a le droit de produire à côté d'un output calc :

```
NarrativeSleeve {
  hook        : 1 phrase, 6-12 mots, ne contient PAS le chiffre
  caption     : 1 phrase, 8-15 mots, traduction en unité signifiante
  next_step   : 1 CTA, 3-5 mots, dérivé d'un input du calc (pas inventé)
  metaphor?   : 1 image locale, optional, depuis dico archetype × canton
}
```

Le calc engine **produit le chiffre, point**. Le LLM **produit la sleeve**, jamais le chiffre. Aucune phrase de la sleeve ne re-affirme le chiffre (anti-pattern : « Ton taux de 63% signifie que tu gardes 63% »). Eval mécanique : un linter qui détecte « le chiffre apparaît dans `hook` ou `caption` » → bloque.

**Pourquoi 6 semaines** : c'est essentiellement un schéma + 3 templates de référence + 1 lint. Pas de nouveau ML.

**Verifiable** : sur 50 outputs calc, 100% ont une sleeve syntaxiquement valide ; 0 ne contient le chiffre dans `hook`.

### 3.2 Move B — Dictionnaire de métaphores locales (archetype × canton × event)

**Quoi** : un fichier JSON/YAML versionné, ~150 entrées, qui mappe `(archetype, canton, life_event, magnitude_bucket)` → une liste de 2-4 métaphores. Le LLM-narrateur pioche ; il n'invente pas.

Exemple concret :

```yaml
- archetype: "swiss_native"
  canton: "VS"
  event: "retirement_gap"
  magnitude_bucket: "moderate"  # gap entre 200k et 500k
  metaphors:
    - "un 2 pièces à Sion, pas la maison"
    - "le mazot, sans la cave"
    - "16 ans de raclette à 2 fois par mois — sauf que c'est pas le sujet"
```

C'est aussi le bon endroit pour discipliner l'humour régional (VOICE_SYSTEM §11.3) : les marqueurs sont *dans le dico*, validés une fois, pas générés à chaque réponse. Diminue radicalement la surface d'erreur du LLM.

**Pourquoi 6 semaines** : ~150 entrées = ~3 jours de copy avec les 8 archetypes × 6 cantons majeurs × 18 events (sub-set des combinaisons réalistes). Lint : 100% des entrées passent le check banned terms + accents.

**Verifiable** : `tools/checks/voice_metaphor_lint.py` → 0 banned term, 0 accent ASCII, ≥2 metaphors per (archetype × canton × event-bucket) actif.

### 3.3 Move C — Une scène dorée par catégorie (DESIGN_SYSTEM §2 A/B/C)

**Quoi** : choisir **3 écrans** (1 Hero A, 1 Simulator B, 1 Life Event C) et les pousser jusqu'au bout du nouveau contrat narrative-sleeve + dico métaphores. Pas une refonte de masse — 3 scènes dorées qui prouvent que calc-first + warmth coexistent.

Recommandation de choix :

| Cat. | Écran | Pourquoi celui-là |
|------|-------|-------------------|
| A Hero | `pulse_screen` | Tier 1, vu chaque session, le test de surface le plus dur |
| B Sim | `rente_vs_capital_screen` | Tier 2, calc rigoureux LPP, narratif sensible (décision quasi-irréversible) |
| C Life | `mariage_screen` | Tier 3, life event sans charge négative, bon terrain pour calibrer la chaleur sans tomber dans le solennel |

Critère de succès : sur ces 3 écrans, un panel de 3 utilisateurs (un VD, un VS, un expat US) lit l'écran à voix haute et **ne peut pas deviner où s'arrête le calc et où commence le LLM**. Si on devine, c'est qu'on est en Excel-with-voiceover.

**Pourquoi 6 semaines** : 3 écrans × 1 semaine de design/copy/wire + 1 semaine de panel test + 1 semaine de buffer. Aligné sur le rythme actuel des perimeters.

**Verifiable** : 3 PRs mergées sur `dev`, sim walker output qui montre le rendu final, panel verbatim consigné dans `.planning/decisions/<date>-warmth-calibration-3-screens.md`.

---

## 4. 3 propositions concrètes pour la roadmap MINT

Au-delà des 6 prochaines semaines, voici 3 propositions de plus longue portée (Q3 2026), classées par ROI estimé décroissant.

### Proposition 1 — Promouvoir « narrative sleeve » au rang de surface de QA mécanique

Actuellement, MINT a des linters pour : banned terms, accents, ARB parity, AAA contrast. Il n'y a **pas** de linter pour la qualité narrative en sortie de LLM.

Proposition : un check `tools/checks/sleeve_lint.py` qui prend un output `(calc_result, sleeve)` et vérifie 6 invariants :

1. `hook` ne contient pas le chiffre du `calc_result`
2. `caption` traduit en unité signifiante (regex « CHF/mois », « % », « ans » présent)
3. `next_step` correspond à un input modifiable du calc (pas inventé)
4. ≤ 30 mots par phrase (anti-pattern §11.2)
5. 0 phrase ouvrant par « Voici ta… » / « Je comprends que… » / « Il est important… » (§11.2)
6. métaphore (si présente) ∈ dictionnaire validé

Test green = condition de merge sur tout PR qui modifie une sleeve template ou un prompt narrator. C'est le **anti-Excel-with-voiceover firewall**. Sans ça, le pivot calc-first dérive en 3 mois.

### Proposition 2 — Redéfinir « confidence » comme propriété narrative, pas seulement numérique

Le calc engine produit déjà des `EnhancedConfidence` (CLAUDE.md NEVER #9 + DESIGN_SYSTEM §5.4). Sur les écrans, on l'affiche en bande grisée + label. C'est *correct mais froid*.

Proposition : la confidence devient un **registre de voix** modulé par le LLM-narrateur :

| Confidence | Voix | Pattern |
|------------|------|---------|
| < 50% | hypothétique, invitante | « Sur la base de ce qu'on a, ça pourrait ressembler à… ». Toujours suivie d'un CTA enrichment. |
| 50-70% | factuelle, calibrée | « C'est l'estimation actuelle. Tes chiffres réels la rapprocheront. » |
| 70-85% | posée, presque tranchée | « Voilà où on en est. » |
| > 85% | sobre, sans modalisation excessive | Le chiffre seul suffit. La sleeve est minimale. |

C'est une mécanique simple (un input du calc → un sélecteur de template) mais elle change tout : la confidence devient *vécue*, pas affichée. Couvre aussi le risque LSFin (les confidences basses sont *par construction* les plus modalisées, donc les plus protégées sur banned terms).

### Proposition 3 — « Narrator memory » light : 3 chiffres, pas un journal

Cleo 3.0 mise tout sur la *long-term memory* du coach. ([techintelpro.com](https://techintelpro.com/news/finance/financial-services/cleo-30-launches-as-ai-financial-coach-with-voice-and-memory)) C'est puissant mais lourd à opérer (RAG, vector store, privacy review LSFin).

Proposition MINT, plus surgical : le LLM-narrateur a accès à **3 chiffres précédents** (pas plus) — par exemple le taux de remplacement de la session précédente, le score de confidence d'il y a 30 jours, et le dernier chiffre que l'utilisateur a regardé > 10s. Ça suffit pour produire des narrations comme :

- « Tu étais à 57 il y a un mois, tu es à 62 maintenant. Le rythme est bon. »
- « C'est le 4e fois que tu reviens sur ton 2e pilier. Ça vaut le coup d'aller jusqu'au bout cette fois ? »

Pas de dossier mémoire géant. Juste 3 ancres temporelles. ROI/coût est imbattable et la privacy surface est minuscule.

---

## 5. Comparatif synthétique — ce qu'on emprunte à qui

| Source | Mécanique empruntée | Mécanique rejetée | Citation |
|--------|---------------------|-------------------|----------|
| Cleo | 20× engagement via personnalité ; modes émotionnels ; LLM-as-coach pas LLM-as-formula-explainer | Roast Mode (trop bruyant pour la Romandie, viole §1 « ce que MINT n'est pas : un influenceur finance ») | [techintelpro](https://techintelpro.com/news/finance/financial-services/cleo-30-launches-as-ai-financial-coach-with-voice-and-memory) ; [econsultancy](https://econsultancy.com/cleo-chatbot-financial-services-persona-marketing/) |
| Wealthsimple | Clarté radicale, paragraphes ≤ 3 lignes, voix active, contractions, traitement humain des sujets stressants | Le rebrand chaud (jaunes/rouges) — palette MINT est noir/blanc/sauge, ne pas dériver | [medium reverse-eng](https://medium.com/@prabhjotbains96_67515/i-reverse-engineered-a-style-guide-for-wealthsimple-heres-what-i-learned-7e5dd5948049) ; [wealthsimple culture](https://www.wealthsimple.com/en-ca/culture) |
| Monarch (Berman) | Money-moment alerts ; gamified micro-commitments ; AI insights = headline + action ; merchant-specific nudges | Sunk-cost paywall (MINT a son propre business model et ce n'est pas un commitment device) | [Berman](https://kristenberman.substack.com/p/monarch-how-a-behavioral-scientist) |
| Copilot Money | Native iOS clean UX ; categorization rules-augmented (déterministe + ML) | Pas vraiment de voix/narration distincte (Copilot reste « pretty calculator », contre-exemple) | [copilot.money](https://www.copilot.money/) |
| Stanford Segel & Heer | Narrative visualization patterns académiques (martini glass, interactive slideshow, drill-down story) | Rien — référence méthodologique, pas un produit | [vis.stanford.edu](http://vis.stanford.edu/files/2010-Narrative-InfoVis.pdf) |
| Bach et al. | 18 narrative design patterns pour data-driven storytelling | Rien — référence méthodologique | [datavis2020](https://datavis2020.github.io/pdfs/Narrative_Design_Patterns__for_Data_Driven_Storytelling.pdf) |
| NN/g calculator UX | Real-time results, traduction en unité signifiante, transparence des hypothèses | Calculatrices sans personnalité (la majorité de l'industrie) | [nngroup](https://www.nngroup.com/articles/calculator-expectations/) |

---

## 6. Counter-argument — quand la chaleur dérive en patronage

C'est le risque majeur. Le pivot 2026-04-12 (« lucidité, pas protection ») a été pris **précisément parce que** la voix MINT antérieure avait dérivé vers du paternalisme déguisé en bienveillance. Si on rajoute une couche narrative chaude sur un calc déterministe, on peut re-dériver en 3 mouvements :

### 6.1 Mécanisme de dérive

1. **Sympathy creep** : le LLM, voulant « illuminer » un chiffre négatif, ajoute des phrases de réassurance non sollicitées. *« Ne t'inquiète pas, on va y arriver ensemble »* → tonalité parent-enfant.
2. **Soft framing** : pour ne pas heurter, le narrateur lisse les chiffres durs. *« Une marge à reconstruire »* au lieu de *« il manque 340'000 »*. Viole VOICE_SYSTEM §4 « Dire la vérité, même inconfortable, avec tact ».
3. **Protective pivot** : à force de protéger l'émotion de l'utilisateur, le produit re-devient « MINT te protège » au lieu de « MINT t'éclaire ». Le pivot d'avril s'auto-annule.

Berman elle-même est ambiguë sur ce point : ses « celebratory alerts » fonctionnent en ROI (80% open rate) mais peuvent infantiliser si calibrées trop chaud.

Cleo a **explicitement choisi** Roast Mode pour éviter ce piège — elle préfère piquer que materner. Ce n'est pas la voie MINT (trop bruyant pour la Romandie), mais le diagnostic Cleo est juste : *la chaleur sans tranchant glisse vers le patronage*.

### 6.2 Mitigation structurelle

Trois fences inscrits dans le contrat narrative-sleeve :

- **Fence 1 — pas de réassurance non sollicitée**. Le `hook` ne contient JAMAIS « ne t'inquiète pas / on va y arriver / pas de panique » sauf si le contexte est explicitement §2 axe 1 « stress ». Lint mécanique.
- **Fence 2 — chiffre dur = chiffre dur**. Le `caption` ne peut pas réduire la magnitude du chiffre. Si calc dit « -340k », caption ne dit jamais « une marge à reconstruire » sans le chiffre. Lint qui croise la sleeve avec le `calc_result`.
- **Fence 3 — pas de « on »-paternaliste**. VOICE_SYSTEM §4 dit « utiliser "on" pour inclure » — légitime — mais le contre-pattern à bannir est « on va t'aider à… ». MINT n'« aide » pas. MINT éclaire.

### 6.3 Test de non-régression

Sur les 3 écrans dorés (Move C), poser la question : *« si je remplaçais MINT par un private banker hyper-poli, est-ce que la voix changerait ? »* Si la réponse est non, c'est qu'on est dans le paternalisme banker-style. C'est un fail.

Cible : MINT sonne plus comme **Le Temps + Wise** que comme un private banker. Net, précis, respectueux de l'intelligence du lecteur. Pas chaud-confortable. Chaud-vrai.

---

## 7. Data gaps & questions ouvertes

Listés explicitement (ce que cette recherche n'a *pas* établi) :

- **Pas de mesure quantitative** sur l'impact narrative-sleeve vs calc-nu sur l'engagement MINT. Recommandation : A/B test sur `pulse_screen` une fois Move A déployé.
- **Pas de validation Romandie** des références culturelles Cleo / Wealthsimple. Cleo est UK Gen Z ; Wealthsimple est Canadian. Le test du local (VOICE_SYSTEM §9bis) doit être fait par 3 natifs (VD/VS/GE) avant tout commit copy.
- **Pas de chiffres** sur la fréquence de dérive paternaliste dans les 50 outputs Stage 3 (Haiku 5/50, Sonnet 21/50). Recommandation : taguer les 28 outputs « failed » de Sonnet selon §6.1 (sympathy creep / soft framing / protective pivot) pour calibrer les fences.
- **Pas d'évaluation côté DE/IT/EN/PT/ES** des patterns proposés. La narrative-sleeve est conçue en FR ; le port multilingue est non-trivial (humor-DE ne traduit pas litote-FR — VOICE_SYSTEM §9). Out of scope ici.
- **Pas de coût LLM estimé** pour Move B (dico métaphores) vs génération à la volée. Le dico réduit drastiquement la surface d'erreur et sans doute les tokens, mais le calc à confirmer.

---

## 8. Verdict de l'expert UX/voice

Le pivot calc-first n'est pas un risque pour la chaleur MINT — **à condition** que le LLM cesse d'être traité comme « narrateur sur des chiffres » et soit redéfini comme « régisseur de scène pour des événements de vie ». Le calc engine fournit la vérité. Le LLM choisit le cadrage, la métaphore locale, le ton du moment. C'est ce qui distingue Cleo (régisseur fort) de Copilot (calc nu, voix faible).

Les trois moves 6-semaines (sleeve formelle, dico métaphores, 3 écrans dorés) suffisent à empêcher la dérive Excel-with-voiceover, *si* les trois fences anti-patronage sont gravés dans le linter dès Move A.

**Risque résiduel** : le glissement chaleur → protection est fin et continu. Il faut un audit narratif tous les ~3 mois (panel 3 natifs, test des 3 écrans dorés, scan des sleeves produites) pour le rattraper avant qu'il ne devienne structurel.

— *Expert 5, fin du brief.*

---

## Sources

- [Berman — Monarch behavioral design (Substack)](https://kristenberman.substack.com/p/monarch-how-a-behavioral-scientist)
- [Wealthsimple style guide reverse-engineered (Medium)](https://medium.com/@prabhjotbains96_67515/i-reverse-engineered-a-style-guide-for-wealthsimple-heres-what-i-learned-7e5dd5948049)
- [Wealthsimple culture manual](https://www.wealthsimple.com/en-ca/culture)
- [Cleo 3.0 voice-and-memory launch (TechIntelPro)](https://techintelpro.com/news/finance/financial-services/cleo-30-launches-as-ai-financial-coach-with-voice-and-memory)
- [Cleo voice-coach feature (WebProNews)](https://www.webpronews.com/uk-fintech-cleo-unveils-ai-financial-coach-with-voice-and-memory-boost/)
- [Cleo persona case study (Econsultancy)](https://econsultancy.com/cleo-chatbot-financial-services-persona-marketing/)
- [Stanford — Narrative Visualization (Segel & Heer)](http://vis.stanford.edu/files/2010-Narrative-InfoVis.pdf)
- [Bach et al. — Narrative Design Patterns for Data-Driven Storytelling](https://datavis2020.github.io/pdfs/Narrative_Design_Patterns__for_Data_Driven_Storytelling.pdf)
- [CHI 2025 — Micro-narratives method](https://dl.acm.org/doi/10.1145/3706598.3713999)
- [NN/g — Calculator and Quiz UX](https://www.nngroup.com/articles/calculator-expectations/)
- [Copilot Money — homepage](https://www.copilot.money/)
- MINT internal: `docs/VOICE_SYSTEM.md`, `docs/DESIGN_SYSTEM.md`, `CLAUDE.md` §6 (banned terms), §9 (0-trust)
