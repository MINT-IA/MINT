---
date: 2026-08-06
status: Proposed
authors: Claude (mint-lead), sur mandat de Julien
panel: single (dossier d'horizon + lecture tuyauterie réelle ; critique croisée Codex en follow-up)
supersedes: —
superseded_by: —
description: Coach navigateur-monstrateur = pont produit, pas lab scripté ni SLM court-terme ; pré-condition = clôture fiscale, câblage invocable par invocable.
related:
  - .planning/decisions/2026-08-06-perimetre-optimisation-fiscale-v1.md
  - .planning/decisions/2026-08-04-experience-navigation-compagnon.md
  - .planning/decisions/2026-08-03-doctrine-reconstruction-mint.md
  - .planning/decisions/2026-07-31-north-star-experience.md
  - docs/VOICE_FIRST_ARCHITECTURE_2028.md
---

# Le coach navigateur-monstrateur tourne dans le pont produit — pas dans le lab scripté

## TLDR

Le coach navigateur-monstrateur (le chat qui route vers l'écran porteur du
chiffre *et* montre un widget fondé sur ce même chiffre) tourne dans le **pont
produit** : le vrai coach backend, dont le pipeline de justesse existe côté
backend (citation gate + freshness gate + outils). Nous écartons le lab scripté
comme *destination* — il prouverait la coquille d'UX en simulant la seule chose
qui distingue MINT de Cleo, la justesse : c'est la « démo sans justesse » nommée
par la doctrine. Sa pré-condition (une surface fiscale réelle où pointer) **est**
le produit de la clôture du thème « Optimisation fiscale v1 » — pas un chantier
de hub séparé. Précision d'inventaire (amendée 2026-08-06, revue Codex) : le
**navigateur** existe en runtime réel ; le **monstrateur à parité receipt**
n'existe pas encore — le premier batch coach le CONSTRUIT, il ne se contente pas
de câbler. Le coach ne se lance qu'après la clôture fiscale, sur *un*
`invocable_id` d'abord.

## Context

Le nouvel ADR « Optimisation fiscale v1 » (mergé sur dev, `78ddd21f2`) fixe le
chantier actif et diffère explicitement le coach :

> « Le coach navigateur-monstrateur reste derrière son ADR d'architecture (où
> tourne-t-il ; pré-condition hub), à écrire sans lancer le chantier coach. »
> (`.planning/decisions/2026-08-06-perimetre-optimisation-fiscale-v1.md`,
> §Decision.)

Ce document tranche cette question. Le dossier d'horizon (scratchpad
`DOSSIER-HORIZON-elargir-vs-approfondir.md`, session 2026-08-05) la pose sans la
trancher : où tourne le coach — un lab scripté qui prouve l'UX, ou le pont
produit qui prouve la justesse ?

**Ce que « navigateur-monstrateur » désigne exactement.** L'ADR navigation
(2026-08-04, §« La thèse — trois couches ») fixe le rôle du chat :

> « Porte d'entrée universelle par l'intention […]. Répond avec des chiffres
> fondés (outils forcés + citations) et finit par le lien profond vers la
> surface qui les porte. L'artefact durable […] vit à l'écran, jamais dans une
> bulle. »

Le **navigateur** = le coach route vers l'écran (chemin profond). Le
**monstrateur** = le coach montre en ligne un widget fondé sur le même chiffre,
portant les mêmes hypothèses et le même disclaimer que l'écran, avant de router
vers lui. Ces deux gestes sont déjà gravés au contrat de la reconstruction, avec
le statut « non implémenté » :

- `product/mint_next/batch21/eclairage-scope.yaml` (bloc `coach_intent`, ~l.396,
  branche `codex/journey-os-batch21-r3` — **pas encore sur dev**) :
  `status: contract_requirement_not_implemented_in_r3` ;
  `invocable_id: eclairage_impot_3a` ; `three_paths_rule:` { `declared_route`,
  `hub_reachable_within_taps: 2`, `natural_language_intents:` [« combien
  j'économise d'impôt avec le 3a », …] } ; `coach_may_show_widget:
  tax_saving_range_widget_grounded_on_this_estimate_with_its_hypotheses` ;
  `widget_must_carry_the_same_hypotheses_and_disclaimer_as_the_screen: true`.
- `product/mint_next/batch22/scenarios_versement-scope.yaml:460` (bloc
  `coach_intent`, branche `codex/journey-os-batch22-r4`) :
  `status: contract_requirement_not_implemented_in_r4` ;
  `invocable_id: scenarios_versement` ;
  `coach_may_offer_own_amount: pulled_by_value_never_a_recommendation` ;
  `coach_may_show_widget: scenarios_spectrum_widget_grounded_on_this_estimate`.

Le contrat existe donc, précis et sous contrainte LSFin (jamais de montant
promis, jamais d'impératif, le coach ne conseille pas un montant). Ce qui manque
est le runtime qui le consomme.

**État réel de la tuyauterie — inventaire contre dev (règle 9).**

1. **Le vrai coach backend existe ; sa justesse est backend, son monstrateur
   n'est pas encore fondé** (amendé 2026-08-06, revue Codex) :
   - `apps/mobile/lib/services/coach/coach_orchestrator.dart:805` déclare une
     liste de quatre outils **offerts au modèle du tier BYOK**
     (`route_to_screen`, `generate_document`, `generate_financial_plan`,
     `record_check_in`) — ce n'est PAS une invocation forcée. Côté server-key
     (`coach_orchestrator.dart:462`→`486`, `/coach/chat`, clé Railway), le
     backend expose un jeu d'outils bien plus large et ne force l'appel que sur
     certains intents (réglementaires / définitions / couple) ; le pipeline de
     justesse est là : `citation_registry.py` (248 l.), `citation_grammar.py`
     (666 l.), `runtime_freshness_gate.py` (237 l.), `coach_tools.py` — tous
     sous `services/backend/app/services/coach/`.
   - `apps/mobile/lib/widgets/coach/widget_renderer.dart:53`→`89` transforme un
     `tool_use` en widget : `route_to_screen` → `_buildRouteSuggestion`
     (`:106`, « Le coach propose ; l'utilisateur décide. No automatic push »),
     qui résout l'intention via `ChatToolDispatcher.resolveRoute` sur le
     `MintScreenRegistry`. MAIS les cartes riches ne garantissent PAS la parité
     avec un receipt d'écran : `show_fact_card` affiche directement
     `value`/`highlight_value` du tool input (`:178-186`), et le fallback du
     plan (`:491-538`, sans plan persisté) affiche `monthly_amount`/
     `monthly_target` issus du payload LLM. **Le monstrateur défini par cet ADR
     (mêmes nombres, mêmes hypothèses, même disclaimer que l'écran) n'existe
     donc pas encore** — c'est l'objet du premier batch coach.
   - **Le navigateur-monstrateur est donc déjà un runtime réel — mais pour la
     surface legacy.** Ses cibles `route_to_screen` sont des routes legacy :
     `screen_registry.dart:429` `/pilier-3a` (`intentTag: simulator_3a`),
     `:451` `/fiscal` (`cantonal_fiscal_comparator`), `:440` `/3a-deep/
     staggered-withdrawal` (`tax_optimization_3a`). Il ne connaît pas les
     `invocable_id` de la reconstruction (`git grep eclairage_impot_3a` sur
     `apps/mobile/**` = vide).
   - Contrainte dure : le coach est calibré `swiss_native` uniquement
     (`coach_orchestrator.dart:335` — `_calibratedArchetypes = {'swiss_native'}` ;
     le défaut true de `enableCoachHardGate` vit dans
     `feature_flags.dart:113-135`), tout autre archétype est refusé avant tout
     dispatch LLM.

2. **L'arc fiscal de la reconstruction n'est pas dans l'app réelle.** Le
   design_lab (`product/mint_next/batch7/design_lab`, surface
   `hidden_design_lab_only`) porte l'arc 3a scripté ; son garde de contrat
   (`tools/checks/mint_next_navigation_contract.py`) « NO-OPS GREEN only when
   BOTH the contract and the Design Lab are absent — the legitimate pre-landing
   state on dev ». Autrement dit : sur dev, l'arc de la reconstruction n'existe
   pas encore ; il vit sur les branches batch en vol. Ses écrans ne sont pas
   promus en routes réelles (aucune interception Strangler Fig mesurable à ce
   jour).

3. **Le SLM on-device est dormant.** `apps/mobile/lib/services/feature_flags.dart:62`
   — `slmPluginReady = false` en valeur initiale ; `main.dart:80-98` tente de
   l'activer, mais le stub `slm_engine.dart:50-84` prouve qu'aucune inférence
   locale ne s'exécute aujourd'hui, même avec `enableSlmNarratives = true`
   (`:37`). Le coach réel = server-key backend ou BYOK.

La question n'est donc pas « construire un coach depuis zéro » — le navigateur
existe — mais « lui donner une surface fiscale réelle et fondée où pointer »,
« construire le monstrateur à parité receipt qui n'existe pas encore », et
« décider si la reconstruction mérite son propre coach ou réutilise celui-ci ».

## Decision

**Le coach navigateur-monstrateur de la reconstruction tourne dans le pont
produit — le vrai coach backend — et nulle part ailleurs comme destination.** Il
ne se lance qu'après la clôture du thème « Optimisation fiscale v1 », en un batch
de câblage mince, sur *un* `invocable_id` à la fois.

**Pourquoi le pont produit, pas le lab scripté.** La raison d'être du coach, per
l'ADR navigation, est que « chaque chiffre doit rester un artefact déterministe
et sourcé » (outils forcés + citations) et que « l'artefact durable vit à
l'écran, jamais dans une bulle ». Cette justesse est backend-canonique (~1400 l.
de citation gate + freshness gate + coach_tools). Un coach scripté dans le
design_lab n'exercerait *aucune* de ces lignes : il montrerait des widgets
cannés sur des données scriptées, prouvant la coquille (le chemin (c) de la règle
des trois chemins) tout en simulant la seule chose qui sépare MINT d'un Cleo. La
doctrine nomme précisément ce piège :

> « le gate "runtime touchable à chaque batch" peut pousser à des démos
> superficielles : un écran qui se tape au doigt n'est pas une preuve de justesse
> actuarielle. » (`2026-08-03-doctrine-reconstruction-mint.md`, §Counter-arguments.)

Le pont produit, à l'inverse, prouve les deux moitiés à la fois : la règle des
trois chemins (navigation réelle) *et* la justesse (le widget monstrateur fondé
sur le receipt, via le harnais de parité coach×receipt déjà mergé, #1114). Le
navigateur n'a pas à être bâti — seulement câblé à une surface réelle ; le
monstrateur fondé, lui, est à CONSTRUIRE (amendé 2026-08-06 : les cartes
actuelles affichent des valeurs du tool input, pas d'un receipt).

**Pourquoi ce n'est pas le prochain batch.** L'ADR fiscal impose de fermer
« Optimisation fiscale v1 » avant tout autre horizon. Lancer le coach maintenant
violerait cet ordre et serait un gros batch (promotion d'arc + hub + câblage),
pas un « petit batch très intelligent ». Le coach reste derrière la clôture.

**La pré-condition « hub » est chiffrée — et n'est pas un coût séparé.** Le
critère de clôture de l'ADR fiscal est l'écran « Tes leviers » (« un utilisateur
voit ses leviers fiscaux, chiffrés honnêtement, au même endroit »). Cet écran
*est* le hub minimal du coach :

- **hub minimal = 6 surfaces fiscales** : les 5 leviers (3a fait ; logement ;
  rachats LPP ; déductions du quotidien ; lieu) + l'écran « Tes leviers » qui
  les rassemble.
- **coût = 0 batch de hub dédié** : ces 6 surfaces sont exactement l'output de
  la clôture du thème fiscal (M batchs = les chapitres 2→5 de l'ADR fiscal + le
  batch de clôture « Tes leviers »). La promotion de l'arc fiscal du design_lab
  vers des routes réelles est la première interception Strangler Fig mesurable ;
  elle appartient au thème fiscal, pas au coach.
- **le coach = +1 batch** après clôture, par-dessus une surface déjà réelle et
  déjà fondée : câblage du navigateur (résolution `invocable_id` → route) ET
  construction du monstrateur à parité receipt (qui n'existe pas encore).
  Chemin (a) de la règle des trois chemins (route déclarée) devient mécanique
  via le garde de contrat ; chemin (b) (≤2 taps depuis « Tes leviers ») est
  tenu par la structure du hub ; le coach ajoute le chemin (c). Ce batch est
  étiqueté **expérimental mono-archétype** (`swiss_native` seul) tant que le
  verrou d'archétypes tient — jamais présenté comme le hub général.

**Définition exacte du premier batch coach (si l'option se lance un jour).**
Gouvernance identique à l'arc 3a (RED contrat scellé → roast indépendant →
runtime touchable, preuves en CI liées au SHA) :

- **Périmètre** : *un seul* `invocable_id` — `eclairage_impot_3a`, le chapitre 1,
  déjà complet et attesté — câblé comme première cible navigateur-monstrateur du
  vrai coach dans l'app réelle. Archétype `swiss_native` uniquement (la porte
  dure `coach_orchestrator.dart:335` reste fermée pour le reste ; l'étendre est
  hors périmètre).
- **Contrat RED (golden eval, avant tout runtime)** : sur les
  `natural_language_intents` gravés (« combien j'économise d'impôt avec le
  3a »…), le coach DOIT émettre (1) un `route_to_screen` vers le bon
  `invocable_id` promu ; (2) un `tax_saving_range_widget` dont les nombres
  égalent le receipt de l'écran (parité coach×receipt, #1114), portant les mêmes
  hypothèses et le même disclaimer ; (3) zéro terme LSFin banni, zéro impératif,
  aucun montant unique promis, jamais un taux en titre. RED d'abord (échoue car
  le coach ne connaît pas encore la surface fiscale promue), puis runtime.
- **Gate runtime touchable** : sur sim, dans l'app réelle, profil
  `swiss_native`, taper « combien j'économise avec le 3a » → le coach route vers
  l'écran éclairage 3a réel + montre le widget fondé → tap ouvre l'écran, qui
  porte le même chiffre. Capture liée au SHA.
- **Explicitement différé** : l'extension au-delà de `swiss_native` ; les quatre
  autres leviers (ajoutés un `invocable_id` à la fois, à mesure que chaque
  chapitre est promu) ; toute voix / tout SLM on-device.

**Le SLM on-device n'est pas un candidat court-terme.** La vision voice-first
(`docs/VOICE_FIRST_ARCHITECTURE_2028.md`) l'exclut elle-même explicitement de la
portée actuelle : « Local model inference — v2.0 uses backend Coach LLM. Edge
computing comes later. These are 2027-2028 features. » (PART 6, l.865). Trois
raisons convergent : (1) le flag est dormant (`slmPluginReady = false`) ; (2) le
document voice-first est hors de l'ADR navigation 2026-08-04, qui ne retient de
l'esprit « ambient » que la proactivité calendaire ; (3) surtout, un modèle
on-device ne peut pas exécuter la justesse — le citation gate, les outils forcés
et le freshness gate sont backend-canoniques. Mettre le coach on-device
*régresserait* la justesse, à l'exact opposé de sa raison d'être. Ce n'est pas un
refus définitif : c'est un « tard et délibéré », comme la stratégie de données.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  L'ADR fiscal porte lui-même la contre-thèse la plus forte : « La rétention naît
  de la mémoire-compagnon […], pas de la largeur d'un thème fiscal […]. Si une
  démo/bêta est imminente, un spike coach assumé comme démo frapperait plus fort
  que l'écran "Tes leviers". » Sur ce point, le lab scripté a un usage légitime
  et étroit : **comme démonstrateur assumé**, jeté après, compté dans le plafond
  méta de 20 % (règle 8), jamais confondu avec l'architecture. Le contrat
  `coach_intent` étant déjà gravé et LSFin-safe, un spike scripté sur le
  design_lab pourrait rendre le geste navigateur-monstrateur *visible* à un
  public sans attendre la clôture fiscale. La thèse adverse dit : ne fais pas de
  la justesse le juge de tout quand ce que tu dois prouver à un investisseur ou
  à un bêta-testeur, c'est que l'app *comprend l'intention et répond au bon
  endroit* — ce qu'un lab scripté montre honnêtement, à condition d'être étiqueté
  démo. Deuxième front adverse : le coach réel est verrouillé à `swiss_native` ;
  tant que ce verrou tient, le « pont produit » ne sert qu'un archétype, et le
  lab scripté (sans garde d'archétype) couvre en réalité *plus* de personas pour
  une démo.

- **What does this source not address ?**
  Aucune donnée d'usage réelle (pas de bêta active) : « le pont prouve mieux que
  le lab » est un jugement analytique, pas une mesure de rétention ou de
  compréhension. Le coût du batch de câblage coach n'est pas chiffré au-delà de
  « mince » — la résolution `invocable_id` → route réelle, le passage du
  `MintScreenRegistry` legacy à un registre incluant les surfaces promues, et la
  parité widget×receipt sur la nouvelle surface n'ont pas été estimés en jours.
  Le verrou `swiss_native` n'a pas de plan de levée daté : on ne sait pas quand
  ni comment le coach couvrira les 8 archétypes, ni si « Tes leviers » lui-même
  doit être `swiss_native`-only. La faisabilité de la promotion Strangler de
  l'arc fiscal (volume d'écrans, dette de câblage legacy) n'est pas mesurée ; on
  suppose qu'elle « appartient au thème fiscal » sans avoir vu le diff. Enfin, le
  monstrateur suppose que chaque écran fiscal expose un receipt exploitable comme
  source de widget : vrai pour le 3a (attesté), non vérifié pour logement / LPP /
  déductions / lieu.

- **What would change this conclusion ?**
  Triggers de re-litigation, mécaniques :
  1. **Une démo/bêta datée** → autoriser un spike lab scripté *comme démo
     assumée* (branche jetable, plafond méta 20 %), sans déclasser le pont
     produit comme destination. C'est le trigger déjà nommé par l'ADR fiscal
     (« bascule vers un spike coach-démo assumé ») ; cet ADR le reprend au lieu
     de le contredire.
  2. **Le batch de câblage coach chiffré à plus d'un micro-batch** (résolution
     d'`invocable_id`, migration de registre, parité widget) → re-scoper : soit
     le découper, soit remonter la promotion de l'arc *dans* le thème fiscal.
  3. **Le verrou `swiss_native` jugé bloquant pour la valeur** (un persona
     non-native central à la démo/bêta) → re-litiger la calibration du coach
     avant de le câbler, car un pont produit mono-archétype vaut peut-être moins
     qu'un lab scripté multi-archétype pour ce besoin précis.
  4. **Une surface fiscale sans receipt exploitable** (logement / LPP / … ne
     produit pas de source de widget fondée) → le monstrateur tombe sur cet
     `invocable_id` ; le câbler alors en navigateur seul (route sans widget) et
     documenter le manque, plutôt que fabriquer un widget non fondé.
  5. **Le voice-first avancé au calendrier** (le flag `slmPluginReady` activé, ou
     l'ADR navigation étendu à la voix) → rouvrir l'option (iii) et son arbitrage
     justesse backend-canonique vs. inférence on-device.

## Sources

- `.planning/decisions/2026-08-06-perimetre-optimisation-fiscale-v1.md` (mergé
  dev `78ddd21f2`) — chantier actif, écran « Tes leviers » comme critère de
  clôture, renvoi explicite à cet ADR.
- `.planning/decisions/2026-08-04-experience-navigation-compagnon.md` — le chat
  comme porte, « l'artefact durable vit à l'écran », règle des trois chemins,
  chat-first écarté à la Cleo.
- `.planning/decisions/2026-08-03-doctrine-reconstruction-mint.md` — « runtime
  touchable » et son contre-argument « démo sans justesse », plafond méta 20 %
  (règle 8), Strangler Fig / legacy-as-library, harnais parité coach×receipt
  (#1114).
- `.planning/decisions/2026-07-31-north-star-experience.md` — D4 « vérités des
  portes + guidage coach », le « vide du coach à l'entrée » comme faiblesse
  observée.
- `apps/mobile/lib/services/coach/coach_orchestrator.dart` — `:335` garde
  `swiss_native` ; `:462`→`486` tier server-key `/coach/chat` ; `:805` la liste
  des quatre outils offerts au tier BYOK (le forçage server-key, sélectif par
  intent, vit côté backend).
- `apps/mobile/lib/widgets/coach/widget_renderer.dart` — `:53`→`89` dispatch
  `tool_use` → widget ; `:96`→`166` navigateur (`route_to_screen`, « le coach
  propose, l'utilisateur décide », résolution via `MintScreenRegistry`).
- `apps/mobile/lib/services/navigation/screen_registry.dart` — `:429` `/pilier-3a`,
  `:440` `/3a-deep/staggered-withdrawal`, `:451` `/fiscal` (les cibles fiscales
  legacy réelles du coach actuel).
- `apps/mobile/lib/services/feature_flags.dart` — `:37` `enableSlmNarratives`,
  `:62` `slmPluginReady = false`.
- `services/backend/app/services/coach/` — `citation_registry.py` (248 l.),
  `citation_grammar.py` (666 l.), `runtime_freshness_gate.py` (237 l.),
  `coach_tools.py` : la justesse backend-canonique.
- `tools/checks/mint_next_navigation_contract.py` +
  `mint_next_navigation_contract_waitlist.yaml` — le garde bidirectionnel et son
  état « NO-OPS GREEN quand contrat et design_lab sont absents sur dev ».
- `product/mint_next/batch21/eclairage-scope.yaml` (bloc `coach_intent` ~l.396,
  branche `codex/journey-os-batch21-r3`) et
  `product/mint_next/batch22/scenarios_versement-scope.yaml:460` (branche
  `codex/journey-os-batch22-r4`) — les blocs `coach_intent` gravés,
  `contract_requirement_not_implemented`. **Non présents sur dev** ; cités depuis
  leurs branches batch.
- `docs/VOICE_FIRST_ARCHITECTURE_2028.md` — PART 6 (~l.862) : inférence locale =
  fonctionnalité 2027-2028, hors portée v2.0.
- Dossier d'horizon : scratchpad session 2026-08-05
  (`DOSSIER-HORIZON-elargir-vs-approfondir.md`).

## Status & follow-up

- Statut : **Proposed** — décision de Julien après lecture. Critique croisée
  Codex APPLIQUÉE le 2026-08-06 (verdict P1: 6 sur la paire d'ADR ; les
  prétentions factuelles de celui-ci corrigées : outils offerts ≠ forcés,
  monstrateur à construire, preuves hard-gate/SLM re-citées, ligne voice-first
  exacte). Le français, la conformité LSFin et l'absence de cadrage
  « retraite-first » re-tenus à l'amendement.
- Réconciliation règle 13 : l'ancien déclencheur fiscal « lab scripté légitime +
  hub minimal peu coûteux » a été RETIRÉ de l'ADR fiscal (amendement
  2026-08-06) car ses conditions étaient satisfaites sans que la conclusion
  suive. Le seul déclencheur qui fait repasser le coach devant est une
  démo/bêta datée (trigger 1 ci-dessus), et alors comme spike assumé, pas comme
  architecture. Les deux ADR sont cohérents sous cette forme.
- Implementation tracking : aucun batch ouvert. Le premier batch coach (défini
  ci-dessus, `invocable_id` `eclairage_impot_3a`, `swiss_native`) ne s'ouvre
  qu'après le scellement de « Tes leviers » et la promotion de l'arc fiscal en
  routes réelles.
- Re-litigation triggers : voir « What would change this conclusion ? ».

---
*Mergé sur dev (#1212) en Proposed ; amendé le 2026-08-06 après la revue
destructrice Codex (avec l'ADR fiscal, même vague d'amendement).*
