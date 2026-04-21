# AGENTS — Flutter role (MINT)

> Loaded on-demand when working in `apps/mobile/` by agents detecting Flutter context.
> Tier 2 (project-specific). Tier 1 = `rules.md`.
> Compagnon doctrinal : `CLAUDE.md` (quickref) + `docs/DESIGN_SYSTEM.md` + `docs/VOICE_SYSTEM.md`.

## 1. Architecture (Flutter scope)

```
apps/mobile/
  lib/
    screens/              # Screens by module
    services/
      financial_core/     # ★ SHARED CALCULATORS — single source of truth
    widgets/              # Reusable widgets + educational inserts
    models/               # Data models
    constants/            # Centralized constants (social_insurance.dart)
    theme/colors.dart     # MintColors palette
    providers/            # Provider state management
    l10n/                 # ARB files (6 languages)
```

## 2. Design System

- **Fonts** : Montserrat (headings), Inter (body) via GoogleFonts. Outfit est déprécié.
- **Colors** : `MintColors.*` depuis `lib/theme/colors.dart` — NEVER hardcode hex.
  - 12 core tokens (voir `docs/DESIGN_SYSTEM.md` §3.2).
  - Jamais `MintColors.text` (n'existe pas) — utiliser `MintColors.textPrimary`.
- **Navigation** : GoRouter — no `Navigator.push`. Routes déclarées dans `app.dart`.
- **State** : Provider (`ChangeNotifierProvider`) — no raw StatefulWidget for shared data.
  - `ProfileProvider`, `BudgetProvider` = patterns existants. No Riverpod, no Bloc.
- **Material 3**, responsive layout, CustomPainter for charts.
- **AppBar** : white background standard. Exception : Pulse uses gradient primary.
- **Deprecated** : `MintGlassCard`, `MintPremiumButton` legacy, font `Outfit` — à ne pas utiliser dans du code neuf.
- **UI Kit** (réutiliser, pas ré-inventer) :
  - `MintCard(child: ...)`
  - `MintSection(title: 'TITRE', children: [...])`
  - `MintPremiumButton(text: 'Label', onTap: () {})`

## 3. i18n (NON-NEGOTIABLE)

- **6 langues** : fr (template), en, de, es, it, pt — ARB files dans `lib/l10n/`.
- **TOUTES les strings user-facing** → `AppLocalizations.of(context)!.key`.
- **Nouvelle string** : ajouter aux 6 ARB files, clés à la FIN (avant `}`).
- **Run `flutter gen-l10n`** après modification des ARB files.
- **French diacritics mandatory** : é, è, ê, ô, ù, ç, à — ASCII "e" à la place de "é" = bug.
- Lint : `tools/checks/accent_lint_fr.py` + `tools/checks/no_hardcoded_fr.py` (Phase 30.5).

## 4. Navigation Architecture (Wire Spec V2)

- **Full spec** : `docs/NAVIGATION_GRAAL_V10.md`.
- **Philosophy** : Coach-first, UI-assisted. AI-as-layer, NOT chatbot-first.
- **Shell** : 3 tabs + drawer — Aujourd'hui | Coach | Explorer + ProfileDrawer (endDrawer).
- **Deep-link compat** : `/home?tab=3` ouvre ProfileDrawer (backward compat ancien Dossier tab).
- **Capture** : contextual bottom sheet (scan, import, add data) — NOT a global FAB.
- **Explorer** : 7 hubs (Retraite, Famille, Travail & Statut, Logement, Fiscalité, Patrimoine & Succession, Santé & Protection).
- **Screen types** : Destination (mental map user), Flow (triggered by intent), Tool (opened contextually), Alias (legacy compat).
- **Archived routes** (Wire Spec V2 P4) : `/ask-mint`, `/tools`, `/coach/cockpit`, `/coach/checkin`, `/coach/refresh` → redirect vers `/home?tab=N`.
- **148 GoRoute documentées** (`ROUTE_POLICY.md`, `SCREEN_INTEGRATION_MAP.md`) — restructuring = UX surface, pas route deletion.

## 5. UX Principles (from `rules.md`)

- Progressive disclosure — no bank connection upfront.
- 1 écran = 1 intention.
- Each recommendation → 1-3 concrete next actions.
- Onboarding minimal : intent + 3 inputs (âge, revenu, canton) avant premier éclairage.
- Precision progressive : ask data when it matters, not during onboarding.
- Score FRI : jamais « bon/mauvais », toujours « progression personnelle ».

## 6. Coach & Arbitrage Rules

- **Coach** : LLM = narrator, never advisor. Fallback templates required (app works without BYOK).
- **Arbitrage** : Always ≥ 2 options side-by-side. Rente vs Capital : always 3 (full rente, full capital, mixed).
- **Hypotheses** : Always visible and editable by user.
- **Sensitivity** : Always shown (« Si rendement passe de X% à Y%, le résultat s'inverse »).
- **Safe Mode** : Si toxic debt détectée → disable optimizations (3a/LPP), priority = debt reduction.
- **CoachContext** : NEVER contains exact salary, savings, debts, NPA, or employer.

## 7. Regional Voice Identity (NON-NEGOTIABLE)

- MINT doit sonner locally rooted selon canton + région linguistique.
- **Suisse Romande** (VD, GE, NE, JU, VS, FR) : « septante/nonante », dry humor, pragmatic. VS = direct/montagnard, GE = cosmopolite, VD = détendu.
- **Deutschschweiz** (ZH, BE, LU, ZG, AG, SG) : « Znüni », savings culture, practical wisdom. ZH = urban/finance-savvy, BE = gemütlich, ZG = tax pride.
- **Svizzera Italiana** (TI, GR partly) : warm Mediterranean flair + Swiss rigor, family savings, grotto references, lake life.
- **Implementation** : `RegionalVoiceService.forCanton()` → `context_injector_service.dart`.
- **Rule** : NEVER caricature. Always subtle — comme un inside joke entre locaux.

## 8. Key anti-patterns (Flutter-specific)

1. Hardcode strings / colors (voir CLAUDE.md quickref triplets #1, #2).
2. Duplicate financial calc logic — utiliser `financial_core/` (triplet #3).
3. `Navigator.push` au lieu de GoRouter.
4. StatefulWidget pour données cross-screen — utiliser Provider.
5. CustomPaint sans wrapper `SentryMask` en contexte Sentry Replay (Phase 31 prep — PII Replay).
6. `_calculate*()` privé dans service — casse single-source-of-truth.

## 9. Anti-Bug Discipline (per MINT_FINAL_EXECUTION_SYSTEM.md §13.7)

Avant ANY implementation :
1. Identify source of truth — quel fichier/modèle est authoritative ?
2. List callsites — qui consomme ce que tu vas changer ?
3. Fix canonical path first — don't patch a fallback if real bug is upstream.

Avant ANY commit :
4. Verify runtime path — trace : UI → navigation → GoRouter.extra → screen → ScreenReturn → handler → store.
5. Check every `onChanged` — chaque slider/dropdown/switch/text field doit set `_hasUserInteracted = true`.
6. Check PopScope timing — `_emitFinalReturn` peut-il fire avant `_readSequenceContext` ?
7. Check route strings — `ScreenReturn.route` matche `GoRoute.path` exactement ?
8. Check flag resets — chaque guard boolean reset dans ALL paths (success + error + unmount) ?
9. Check units — values gross/net, annual/monthly, ratio/percentage cohérents ?

Après ANY commit :
10. Auto-audit — lister : bug le plus probable restant, joint le moins prouvé, fallback le plus risqué.

## 10. Testing Patterns

```dart
// Widget test with GoRouter
final router = GoRouter(routes: [
  GoRoute(path: '/', builder: (_, __) => const MyScreen()),
]);
await tester.pumpWidget(MaterialApp.router(routerConfig: router));

// Mock SharedPreferences toujours
SharedPreferences.setMockInitialValues({});

// Viewport for reliable layout
tester.view.physicalSize = const Size(1440, 3200);
tester.view.devicePixelRatio = 2.0;
```

- Smoke test obligatoire dans `test/screens/` pour chaque nouveau screen.
- `flutter analyze` 0 issues + `flutter test` green avant commit.

## 11. Reference docs for Flutter work

- `docs/DESIGN_SYSTEM.md` — tokens, components, screen categories, checklist.
- `docs/VOICE_SYSTEM.md` — 5 piliers, 50 avant/après, microcopy.
- `docs/NAVIGATION_GRAAL_V10.md` — full IA.
- `docs/UX_WIDGET_REDESIGN_MASTERPLAN.md` — UX 7 laws + 75 propositions.
- `.claude/skills/mint-flutter-dev/SKILL.md` — skill opérationnel (UI kit, chantiers actifs).
