# PANEL D — Devil's Advocate

**Rôle** : architect·e ex-Linear / ex-Stripe / ex-Mercury. Vu 3 "grandes refontes docs/context" échouer dans 3 boîtes différentes. Position : **Phase 30.5 telle que proposée est une mauvaise idée.** Pas "à ajuster". À **rejeter dans sa forme actuelle**.

---

## 1. Pourquoi Phase 30.5 est une erreur stratégique

**(a) Perfection paralysie dressée en foundation.** 2 semaines de budget dur "non-empruntable" pour réécrire *du texte*. Dans un monde où Julien a shippé 5 waves en 1 journée autonome (2026-04-18, 42K LOC supprimées, 0 régression), dépenser 10 jours productifs sur CLAUDE.md/MEMORY.md avant Phase 31 signifie perdre 14% du budget v2.8 restant (31-36) sur un artefact qui n'exécute aucun test, ne corrige aucun P0, ne ferme aucune des 388 bare catches. C'est un détournement d'ambition déguisé en rigueur.

**(b) "Panel d'experts" pour du markdown = théâtre.** CLAUDE.md n'est pas un système distribué. Pas une spec API. Pas un schéma fiscal. C'est un fichier de 400 lignes qui sert à câliner le system prompt d'un LLM. Convoquer "ex-Anthropic prompt engineer + ex-Stripe DX + ex-Cursor agent-context + ex-Linear doc lead" pour ça, c'est la bureaucratie comme substitut d'action. Linear n'a pas de panel pour son CONTRIBUTING.md. Stripe non plus.

**(c) Les agents divergent — un problème LLM, pas un problème doc.** Les accents oubliés, le code recréé, le contexte perdu : ce sont des symptômes de Claude Code lui-même (context window, tokenizer non-déterministe, sampling, prompts système opaques). Plus-de-doc a une élasticité décroissante : 400 lignes → 150 lignes n'améliorera pas la fidélité si le vrai ennemi est que l'agent ne lit pas le fichier au bon moment. **On ne corrige pas un bug d'inférence avec de la prose**.

**(d) Le pattern déjà-vu tue cette proposition.** v2.4 "Fondation", v2.6 "Coach Qui Marche", v2.7 "Stabilisation", maintenant v2.8 "L'Oracle" avec une 30.5 "Context Foundation" *qui vient AVANT la foundation* : c'est une foundation-de-la-foundation. Pitfall G1 de `research/SUMMARY.md` est explicite : "v2.8 risque devenir prélude v2.9". Phase 30.5 est exactement ce dont le pitfall avertit. L'ADR kill-policy dit "si v2.8 échoue, on kill features, on ne crée pas v2.9 stabilisation" — alors pourquoi créer v2.7.5 stabilisation sous le nom "30.5" ?

---

## 2. Alternatives

**Radical 1 — Tuer CLAUDE.md entièrement.** Le remplacer par 8 skills loaded-on-demand : `mint-flutter-dev`, `mint-backend-dev`, `mint-swiss-compliance`, `mint-commit`, `mint-test-suite` (existent déjà), + 3 nouveaux `mint-identity`, `mint-compliance-rules`, `mint-archetype-guide`. Contexte chargé seulement quand l'agent en a besoin — pas 400 lignes injectées à chaque spawn. Coût : 1 jour. Gain : tokens/tâche ÷ 3.

**Radical 2 — Zéro refonte. Tout le budget dans les lints qui mesurent.** `no_bare_catch.py`, `accent_lint_fr.py`, `no_hardcoded_fr.py`, `arb_parity.py` (déjà tous dans GUARD-02/03/04/05). Si le lint passe, la doc est bonne *enough*. Mesure > prose. Le lint refuse le commit qui introduit `creer` au lieu de `créer` — la doc devient redondante par construction. Bonus : s'applique même si l'agent n'a rien lu.

**Modeste 1 — 2 jours au lieu de 2 semaines.** Split CLAUDE.md en 4 fichiers ciblés (`IDENTITY.md`, `CONVENTIONS.md`, `CONSTANTS.md`, `ANTI-PATTERNS.md`) + `tools/memory/gc.py` qui tronque MEMORY.md à 200 lignes en archivant le reste. Fait. Pas de panel, pas de 2 semaines, pas d'ADR.

**Modeste 2 — Dogfood first (Phase 35 avant 30.5).** Lance `mint-dogfood.sh` en PREMIER. Mesure le drift agent **réel en prod** pendant 7 jours. Construis CLAUDE.md v2 basé sur observations concrètes (quels accents cassent vraiment ? quel code est vraiment re-créé ?) au lieu de suppositions de panel. Feedback loop courte > expert panel spéculatif.

---

## 3. Le vrai bug n'est peut-être pas la doc

- **Les prompts système Claude Code eux-mêmes** — opaques, non-contrôlables, changent entre releases. Aucune refonte CLAUDE.md ne survivra à un upgrade SDK.
- **Les skills ne sont pas invoqués** — `mint-swiss-compliance`, `mint-flutter-dev` existent mais les agents spawnent sans les appeler. Le problème est de **routing**, pas de contenu.
- **MEMORY.md tronqué à 200 lignes ignore les handoffs récents** — ironique : la règle des 200 lignes qui est censée aider *cause* le drift, parce que le handoff Wave C du jour est coupé avant d'être lu. GUARD-10 aggrave le symptôme qu'il prétend traiter.
- **Pas de feedback loop courte** — l'agent code 3h, on découvre la casse après. Phase 35 (dogfood quotidien) répond à ça. **30.5 ne répond à rien de mesurable**.

---

## 4. Stress-test GUARD-09/10/11

- **GUARD-09 "target ~150 lignes"** — quelle étude ? Cursor documentation recommande jusqu'à 500 lignes. Certaines grosses codebases (Sentry, Vercel) ont 2000+ lignes de rules et shippent très bien. **150 est un chiffre anxieux, pas empirique.** Si la mesure "tokens/tâche −40%" est l'objectif, on peut l'atteindre avec 250 lignes bien structurées aussi bien qu'avec 150 mal serrées. Le chiffre est un leurre.
- **GUARD-10 "MEMORY.md <200 lignes HARD"** — et si l'utile dépasse 200 ? On tronque du signal actif (handoff Wave C de 2026-04-19, cf. MEMORY.md ligne 9-10) pour respecter une règle arbitraire. **La limite runtime (200 lignes loaded) n'est pas la bonne cible — la bonne cible est "tout le handoff actif est chargé".** Inverser : `gc` archive tout ce qui a >30j, garde le reste même si ça fait 400 lignes.
- **GUARD-11 "proof-of-read AST"** — si chaque commit agent prend +30s pour écrire un `READ.md`, les agents skipperont (ou Julien passera à `LEFTHOOK_BYPASS=1`, cf. GUARD-07 qui documente déjà l'abus prévisible). Pire : un agent peut lister les fichiers sans les lire (faux proof). **Mécanisme non-vérifiable = théâtre de conformité.**

---

## 5. Recommandation ferme

**NON à Phase 30.5 telle que scopée.** Descoper à 2 jours max (Modeste 1), lancer Phase 35 dogfood AVANT toute refonte doc (Modeste 2), et mettre le budget "panel" dans les lints mesurables (GUARD-02/03/04/05 ship immédiatement, les vrais gardiens — pas GUARD-09/10/11 qui sont de la doc-gym).

Si Julien maintient 30.5 à 2 semaines : c'est v2.9 stabilisation déguisée, la kill-policy ADR du 2026-04-19 s'applique à lui-même, et on perd 14% du budget v2.8 sur un markdown que le prochain upgrade Claude Code ré-cassera.
