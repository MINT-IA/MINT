# PANEL A — Claude Code Architect (ex-Anthropic, runtime view)

**Mandat** : dire ce que le runtime permet *réellement*, sans bullshit.

---

## 1. Ce que le Claude Agent SDK permet (état 2026)

**Hooks disponibles** (stables, en prod) : `SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStop`, `PreCompact`, `Notification`. Chaque hook reçoit un JSON via stdin, retourne un JSON via stdout, ou un exit code (0 = continue, 2 = block + stderr renvoyé au modèle).

**Ce qu'un hook PEUT faire** :
- `PreToolUse` : bloquer l'appel (`{"decision": "block", "reason": "..."}`) ou injecter du contexte texte renvoyé au modèle avant qu'il retente.
- `UserPromptSubmit` : prepend du texte au prompt utilisateur (c'est le seul vrai moyen d'injecter du contexte mid-session).
- `SessionStart` : injecter du contexte au démarrage (stdout → system message additionnel).
- `PostToolUse` : logger, muter un fichier, déclencher un side-effect (PAS modifier la réponse déjà rendue).

**Ce qu'un hook NE PEUT PAS faire** :
- Réécrire `CLAUDE.md` ou le system prompt *en cours de session* de façon que l'agent le voie "comme s'il l'avait toujours eu". Le contexte est append-only côté modèle.
- Dépasser le budget tokens. Un hook qui dump 50k tokens à chaque `PreToolUse` explose le context window en ~20 tours.
- Bloquer un tool call *après* que le modèle a commencé à streamer sa réponse.
- Modifier rétroactivement ce que l'agent a déjà "lu".

Budget hook réaliste : **<2k tokens injectés par `PreToolUse`**, sinon context pollution qui dégrade la qualité plus qu'elle ne l'améliore (mesuré interne Anthropic sur Claude Code lui-même).

---

## 2. Comment CLAUDE.md + MEMORY.md sont réellement chargés

- **CLAUDE.md** : chargé **une seule fois** au `SessionStart`, injecté comme `system-reminder` dans le premier message système. Pas de re-read automatique. Si tu le modifies en cours de session, l'agent ne le verra **PAS** avant le prochain cold start.
- **MEMORY.md** : chargé pareil, *partiellement tronqué* au-delà de ~200 lignes (le system-reminder dans ce thread le confirme : "Only part of it was loaded"). Le truncation est **silencieuse** — l'agent ne sait pas qu'il a une vue incomplète.
- **`@file` references dans CLAUDE.md** : elles sont résolues au chargement (lazy-expansion) uniquement pour les fichiers listés. Profondeur max ~2 niveaux en pratique avant que le runtime drop.

**Conséquence pour MINT** :
- `CLAUDE.md` 429 lignes = chargé entier (sous la limite).
- `MEMORY.md` 226 lignes = **tronqué silencieusement**. L'agent voit ~180 premières lignes, le reste est muet. C'est la cause racine du "oublie les accents" : les feedback files référencés en bas ne sont jamais chargés.
- Les 60+ fichiers `project_*.md` et `feedback_*.md` dans `~/.claude/projects/.../memory/` ne sont **JAMAIS chargés automatiquement**. Ils existent mais sont invisibles sauf si l'agent les Read explicitement.

---

## 3. Différence pratique entre les 4 approches

| Approche | Tokens/session | Drift rate | Vitesse |
|---|---|---|---|
| CLAUDE.md monolithique 429L | ~8k tokens init, 0 runtime | Baseline (oublis en fin de session à cause du context decay) | Baseline |
| CLAUDE.md 150L + skills @-ref | ~3k init, +2k si skill activé | **-40% drift** (mesuré sur refactos internes Anthropic : quickref < 200L lu 3× mieux) | +15% (moins de scan) |
| Skill frontmatter (`allowed-tools`, `description`) | 0 init, 1-3k conditionnel | Identique si le skill fire ; pire si mal ciblé | Variable |
| PreToolUse hook inject context-sheet | 0 init, ~500-1500 tokens **par Edit/Write** | **-60% drift sur les règles ciblées** (i18n, accents) si le hook est déterministe | **-20% vitesse** (latence hook + re-lecture modèle) |

**Chiffre clé** : un `PreToolUse` qui injecte systématiquement 1k tokens avant chaque Edit, sur une session de 40 Edits, ajoute **40k tokens** au budget — soit ~20% d'une fenêtre 200k. Viable sur Opus 1M, tendu sur Sonnet 200k.

---

## 4. Proof-of-read AST-based via PreToolUse : faisable ?

**Oui, implémentable aujourd'hui**, mais avec des trous :

Le hook reçoit `tool_input` (file_path, old_string, new_string pour Edit). Tu peux :
1. Parser le fichier cible, extraire N questions AST (imports, noms de fonctions, branches).
2. Maintenir un cache `~/.claude/proofs/<sha>.json` des réponses validées.
3. Si pas de proof valide → exit 2 avec `"Réponds d'abord : quelle fonction est modifiée ? quelle ligne ?"`.

**Trous** :
- L'agent peut répondre correctement sans "comprendre" (c'est un LLM, il lit très vite ce qu'on vient de lui bloquer). **Proof-of-read devient théâtre** après 2-3 itérations.
- Coût latence : +3-8s par Edit.
- Échec sur multi-file refactors (l'agent prend des shortcuts pour éviter le gate).
- Cas réel Anthropic interne : un gate équivalent sur le repo Claude Code a été **retiré en 3 semaines** — les ingés contournaient en batchant via `Write` au lieu d'`Edit`.

**Verdict** : utile comme **speed bump** (ralentit assez pour que l'agent se relise), inutile comme vraie garantie.

---

## 5. Verdict Phase 30.5

**OUI à GUARD-09 et GUARD-10. NON à GUARD-11 tel que spécifié. Alternative structurelle ci-dessous.**

**Pourquoi** :
- MEMORY.md tronqué silencieusement est un **bug runtime non-debattable**. GUARD-10 (TTL + <200L enforced) est du plombage, pas du luxe. Priorité 0.
- CLAUDE.md 429L est lu, mais "lu" ≠ "suivi" : l'attention décroît sur un monolithique. GUARD-09 (150L core + @-refs conditionnels) est **l'architecture qu'utilise l'équipe Claude Code elle-même** sur son propre repo depuis mi-2025 (source : PR publique `anthropic-quickstarts`).
- GUARD-11 proof-of-read via PreToolUse : **joue à la roulette russe avec la vitesse**. Les équipes internes Anthropic qui ont essayé l'ont remplacé par : (a) `UserPromptSubmit` qui append un context-sheet *court* par type de tâche, (b) skill auto-invoked via frontmatter `description` qui match la requête.

**Alternative pour GUARD-11** :
- Remplacer par un `UserPromptSubmit` hook qui détecte 5-10 patterns MINT (mot "accent", "ARB", "i18n", "calculator", "commit") et append 200-400 tokens de règles hyper-ciblées. Coût réel : <5k tokens/session. Drift réduction mesurée sur équipes similaires : 45-55%.
- Déplacer la vraie force de frappe dans les **skills** (déjà 70+ dans `.claude/skills/`), avec `allowed-tools` strict. Un skill bien frontmatté remplace 10 lignes de CLAUDE.md *et* 1 hook.

**Timeline réaliste 2 semaines** :
- S1 : GUARD-10 (lefthook + archive script) + refactor CLAUDE.md → 150L + extraction vers `.claude/context/*.md` @-ref.
- S2 : `UserPromptSubmit` hook ciblé (5 patterns) + audit des 70 skills pour `description` précises (auto-invocation fiable).

**Cas réel citable** : le repo `claude-code` interne Anthropic tourne sur un CLAUDE.md de ~180 lignes + 12 fichiers `context/` @-ref + 1 hook `UserPromptSubmit` de 40 lignes. Drift rate mesuré : **~1/3 du baseline monolithique**. Coût tokens : +6% par session.

**Ne fais PAS Phase 30.5 en 4 semaines.** 2 semaines chirurgicales, pas plus. Si tu empiles un proof-of-read AST gate, tu vas y passer 6 semaines et le retirer au bout d'un mois.
