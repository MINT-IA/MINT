# Phase A-USER-WALKTHROUGH — Context

**Gathered:** 2026-05-06 evening
**Status:** Ready for planning
**Mode:** Founder-mandated, max speed

<domain>
## Phase Boundary

After 5 months of test infrastructure (walkers, fixtures, panels, doctrines), no human has actually used MINT end-to-end. Tonight: I (Claude, via xcrun simctl + idb on iPhone 17 Pro sim) walk through the production flow with NO MINT_E2E_* dart-defines, only `API_BASE_URL=https://mint-staging.up.railway.app/api/v1`. I document every screen plainly in French, what works, what crashes, what doesn't navigate.

Single output : `docs/USER_WALKTHROUGH_2026-05-06.md` at repo root (NOT in `.planning/`, deliberately public-facing).

</domain>

<decisions>
## Implementation Decisions

### Build configuration
- Flutter debug build (kReleaseMode = false but NO replay-cache flag — replay defaults to live in mode getter when `MINT_LLM_CACHE_MODE` is unset)
- Only dart-define : `API_BASE_URL=https://mint-staging.up.railway.app/api/v1` + `MINT_DISABLE_BETA_MODAL=true` (otherwise the modal blocks the walk)
- NO `MINT_E2E_ARCHETYPE`, NO `MINT_E2E_FORCE_ECLAIRAGE_KIND`, NO `MINT_LLM_CACHE_MODE` set
- Sim erased fresh per SIMH-01 to simulate a new user

### Walk method
- xcrun simctl io booted screenshot for each screen
- idb ui describe-all + idb ui tap for navigation
- Real prompts typed via idb ui text (« Combien je peux mettre dans un 3a ? » etc.)
- Wait 5-30s between actions for animations + LLM responses
- Capture each screen to `.planning/phases/A-USER-WALKTHROUGH/screenshots/`

### Documentation format
Each step in `docs/USER_WALKTHROUGH_2026-05-06.md` :
- Étape N : ce que j'ai fait (action humaine plate)
- Ce que j'ai vu (screenshot path + description en français plat)
- Verdict : ✅ marche / ⚠️ étrange / 🚨 cassé
- Si cassé : la ligne de code probable + fix d'1 ligne suggéré

### Goldenpath user persona
Pas de profil pré-rempli. Pas de canton forcé. Juste un humain anonyme qui ouvre l'app, tape « Bonjour », répond aux questions, essaye d'aller au bout.

### Coverage target
- Anonymous chat 3 turns ✓ requis
- Auth gate ✓ requis
- Register flow ✓ requis si pas trop bloquant
- Onboarding screens ✓ requis (au moins jusqu'au premier insight)
- Documents upload (PDF) ✓ tenté avec un PDF bundlé
- Scenarios / projections ✓ tenté
- Arrêt si plus de 5 crashes successifs sur le même flow

### Claude's discretion
- Choix des prompts à taper (« Bonjour », « J'ai 35 ans, j'aimerais comprendre mon 3a » etc.)
- Ordre d'exploration des features post-auth
- Quand abandonner une branche cassée et passer à la suivante

</decisions>

<code_context>
## Existing Code Insights

### Reusable assets
- `tools/simulator/walker_premier_eclairage.sh` — sim hygiene + flutter build + install + launch (réutilise tel quel pour la phase L0, mais on coupe les MINT_E2E_* flags)
- `tools/simulator/maestro_env.sh` — idb python client + JAVA_HOME wiring (ne pas appeler Maestro tonight, mais le PATH fix est utile)
- `apps/mobile/lib/screens/` — 30+ écrans à découvrir au fil du walk

### Established patterns
- Sim hygiene : `xcrun simctl shutdown all → erase → boot`
- Build : `flutter build ios --simulator --debug --no-codesign --dart-define=API_BASE_URL=...`
- Install : `xcrun simctl install booted Runner.app`
- Launch : `xcrun simctl launch booted ch.mint.app`

### Integration points
- Backend Railway staging : `https://mint-staging.up.railway.app`
- Anthropic via backend `/anonymous/chat` endpoint
- Auth via existing flow (Apple Sign In or email/password)

</code_context>

<specifics>
## Specific Ideas

- Documenter en français plat, pas de jargon
- Une étape = un paragraphe + un screenshot
- Pas de panel, pas de doctrine, pas de claim « green »
- Tone : « j'ai cliqué X, j'ai vu Y, ça marche / ça casse à cause de Z »

</specifics>

<deferred>
## Deferred Ideas

- Maestro flow refactor (déjà couvert par doctrine 2026-05-06-test-theater)
- Promptfoo eval setup (Phase week 2 par doctrine)
- Compliance Control Matrix (Phase week 4 par doctrine)

Tout ça attend lundi. Tonight = le walk humain, point.

</deferred>
