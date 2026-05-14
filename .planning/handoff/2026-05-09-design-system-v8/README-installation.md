# Installation dans le repo MINT

Ce dossier contient **tout ce qu'il faut** pour démarrer l'implémentation MINT v2 dans le codebase Flutter via Claude Code.

## Quoi

```
docs/brand/                ← référence visuelle (brand sheet + écrans)
  ├── MINT-brand.html      ← brand sheet verrouillé (à garder ouvert pendant le dev)
  ├── MINT-screens.html    ← canvas des 8 écrans clés en menthe + clair
  ├── colors_and_type.css  ← tokens CSS (référence)
  └── mint-v2/             ← sources React (référence pour les composants)

handoff/                   ← brief pour Claude Code
  ├── 00-README.md         ← index — commence ici
  ├── ARCHITECTURE.md      ← LE doc central (3 couches, ScreenRegistry, RoutePlanner)
  ├── architecture.html    ← schéma visuel de l'architecture
  ├── 01-vision.md         ← pourquoi le chat doit MONTRER
  ├── 02-chat-vivant-services.md
  ├── 03-components.md     ← composants Flutter à créer/adapter
  ├── 04-animations.md     ← timings et courbes
  ├── 05-integration.md    ← branchement dans le chat existant
  ├── 06-test-plan.md      ← golden tests + invariants
  ├── CLAUDE_CODE_PROMPT.md      ← LE prompt à coller dans Claude Code
  ├── CLAUDE_CODE_FIX_PROMPTS.md ← prompts de correction si dérive
  └── prototype/                 ← prototype HTML du chat vivant + captures de référence
      ├── MINT - Chat vivant.html
      ├── chat-vivant/           (sources React)
      ├── captures/              (screenshots clés)
      └── ios-frame.jsx
```

## Comment installer

Dans le repo MINT (à la racine) :

```bash
# Depuis ton terminal VS Code, à la racine du projet MINT :
cp -r _to-MINT/docs/brand docs/brand
cp -r _to-MINT/handoff handoff
git checkout -b feat/mint-v2-refondation
git add docs/brand handoff
git commit -m "docs: brand sheet locked + handoff package"
```

## Ensuite

1. Ouvre `handoff/CLAUDE_CODE_PROMPT.md`
2. **Colle PROMPT 1** dans Claude Code (VS Code)
3. Output attendu : une **note de cadrage écrite, pas du code**
4. Tu valides la note (ou tu corriges sa compréhension)
5. Puis PROMPT 2 (audit ScreenRegistry) — **ne saute jamais une phase**
6. Puis PROMPT 3 (chat vivant)

## Garde toujours ouvert pendant le dev

- `docs/brand/MINT-brand.html` ← référence visuelle absolue
- Si Claude Code propose un rendu qui s'en écarte → tu lui pointes
