---
phase: quick-260412-kue
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart
  - apps/mobile/lib/theme/colors.dart
  - apps/mobile/lib/app.dart
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_pt.arb
autonomous: true
requirements: []
must_haves:
  truths:
    - "Unauthenticated user sees warm white screen with timed text sequence and 6 felt-state pills"
    - "Tapping a pill navigates to /coach/chat with that pill text as initialPrompt"
    - "Typing free text and submitting navigates to /coach/chat with that text as initialPrompt"
    - "Shell tabs are NOT visible — screen is full-screen outside StatefulShellRoute"
    - "All strings come from ARB files in 6 languages with cultural adaptations"
  artifacts:
    - path: "apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart"
      provides: "Full-screen anonymous intent screen with timed animation sequence"
    - path: "apps/mobile/lib/theme/colors.dart"
      provides: "MintColors.warmWhite constant"
  key_links:
    - from: "anonymous_intent_screen.dart"
      to: "/coach/chat?prompt=..."
      via: "GoRouter context.go with prompt query param"
      pattern: "context\\.go.*coach/chat.*prompt"
---

<objective>
Implement the anonymous intent screen — MINT's first screen for unauthenticated users. Two opening lines fade in sequentially, then 6 felt-state pills appear staggered, plus a free-text field. Any interaction routes to the coach chat with the user's intent as initialPrompt. No shell, no logo, no login — pure emotional entry point.

Purpose: Replace the current LandingScreen at '/' for unauthenticated users with an experience that meets the user where they are emotionally, not informationally.
Output: Working anonymous intent screen routed at '/' for unauthenticated users.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@apps/mobile/lib/app.dart (router — route '/' currently points to LandingScreen)
@apps/mobile/lib/theme/colors.dart (MintColors palette — add warmWhite)
@apps/mobile/lib/screens/coach/coach_chat_screen.dart (accepts initialPrompt param)
@apps/mobile/lib/widgets/coach/lightning_menu.dart (staggered animation pattern reference)
@apps/mobile/lib/l10n/app_fr.arb (i18n template — add keys at END before closing brace)

<interfaces>
<!-- Router: '/' route uses ScopedGoRoute with RouteScope.public -->
<!-- Coach chat accepts ?prompt= query param → initialPrompt constructor arg -->
<!-- MintColors: static const Color fields, premium palette section exists -->
<!-- ARB: camelCase keys, @key metadata with description, add before final } -->
</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add i18n keys for anonymous intent screen (6 ARB files) + warmWhite color</name>
  <files>
    apps/mobile/lib/theme/colors.dart,
    apps/mobile/lib/l10n/app_fr.arb,
    apps/mobile/lib/l10n/app_en.arb,
    apps/mobile/lib/l10n/app_de.arb,
    apps/mobile/lib/l10n/app_it.arb,
    apps/mobile/lib/l10n/app_es.arb,
    apps/mobile/lib/l10n/app_pt.arb
  </files>
  <action>
**colors.dart**: Add `static const Color warmWhite = Color(0xFFFAF8F5);` in the premium palette section (after `corailDiscret`).

**ARB files** — Add these keys at the END of each file (before final `}`). These are CULTURAL ADAPTATIONS, not literal translations. Each language must feel native and emotionally resonant for that culture.

Keys to add (9 keys):

1. `anonymousIntentLine1` — Opening line about money being taboo
2. `anonymousIntentLine2` — Follow-up "even to yourself"
3. `anonymousIntentPill1` — "I pay, I sign, but I don't understand everything"
4. `anonymousIntentPill2` — "I avoid thinking about it"
5. `anonymousIntentPill3` — "I'm afraid of making a mistake"
6. `anonymousIntentPill4` — "I know I should deal with it"
7. `anonymousIntentPill5` — "Something changed and I don't know where to start"
8. `anonymousIntentPill6` — "I just want to see clearly"
9. `anonymousIntentFreeTextHint` — Placeholder for text field "Or say it your way..."

**French (template):**
```
"anonymousIntentLine1": "L'argent, en Suisse, c'est le sujet dont personne ne parle.",
"@anonymousIntentLine1": {"description": "Anonymous intent screen — opening line about money taboo in Switzerland."},
"anonymousIntentLine2": "Même pas à soi-même.",
"@anonymousIntentLine2": {"description": "Anonymous intent screen — follow-up line."},
"anonymousIntentPill1": "Je paye, je signe, mais je comprends pas tout",
"@anonymousIntentPill1": {"description": "Anonymous intent — felt-state pill 1."},
"anonymousIntentPill2": "J'évite d'y penser",
"@anonymousIntentPill2": {"description": "Anonymous intent — felt-state pill 2."},
"anonymousIntentPill3": "J'ai peur de faire une connerie",
"@anonymousIntentPill3": {"description": "Anonymous intent — felt-state pill 3."},
"anonymousIntentPill4": "Je sais que je devrais m'en occuper",
"@anonymousIntentPill4": {"description": "Anonymous intent — felt-state pill 4."},
"anonymousIntentPill5": "Un truc a changé et je sais pas par où commencer",
"@anonymousIntentPill5": {"description": "Anonymous intent — felt-state pill 5."},
"anonymousIntentPill6": "Je veux juste y voir clair",
"@anonymousIntentPill6": {"description": "Anonymous intent — felt-state pill 6."},
"anonymousIntentFreeTextHint": "Ou dis-le comme tu veux\u2026",
"@anonymousIntentFreeTextHint": {"description": "Anonymous intent — free text input hint."}
```

**English** — Adapt culturally (money taboo in Anglo-Swiss context):
- Line 1: "Money in Switzerland. The thing nobody talks about."
- Line 2: "Not even to themselves."
- Pills: natural English phrasing (e.g., "I pay, I sign, but I don't really get all of it", "I just avoid thinking about it", "I'm scared of making a costly mistake", "I know I should be on top of this", "Something changed and I have no idea where to start", "I just want to see clearly")
- Hint: "Or say it in your own words..."

**German** — Swiss German feel, direct, pragmatic:
- Line 1: "Geld. In der Schweiz redet niemand darüber."
- Line 2: "Nicht mal mit sich selbst."
- Pills: natural DE phrasing adapted to Swiss directness
- Hint: "Oder sag es so, wie du willst..."

**Italian** — Ticino warmth with Swiss rigor:
- Line 1: "I soldi, in Svizzera, sono il tema di cui nessuno parla."
- Line 2: "Nemmeno con sé stessi."
- Pills: warm Italian phrasing
- Hint: "Oppure dillo come vuoi tu..."

**Spanish** — Clear, approachable:
- Line 1: "El dinero, en Suiza, es el tema del que nadie habla."
- Line 2: "Ni siquiera con uno mismo."
- Hint: "O dilo a tu manera..."

**Portuguese** — Similar warmth:
- Line 1: "O dinheiro, na Suíça, é o assunto de que ninguém fala."
- Line 2: "Nem consigo mesmo."
- Hint: "Ou diz como quiseres..."

Each ARB entry MUST have the `@key` metadata line with description. Add all 18 lines (9 keys + 9 metadata) before the final `}` in each file.

After editing all ARB files, run: `cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter gen-l10n`
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter gen-l10n 2>&1 | tail -5</automated>
  </verify>
  <done>MintColors.warmWhite exists. All 6 ARB files have 9 anonymousIntent* keys. flutter gen-l10n succeeds with no errors.</done>
</task>

<task type="auto">
  <name>Task 2: Create AnonymousIntentScreen with timed animation sequence</name>
  <files>apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart</files>
  <action>
Create `apps/mobile/lib/screens/anonymous/anonymous_intent_screen.dart`.

**Structure:**
- `AnonymousIntentScreen` StatefulWidget
- Uses `TickerProviderStateMixin` for multiple AnimationControllers

**Animation timeline (use AnimationController + Future.delayed):**
- t=0: Scaffold with `MintColors.warmWhite` background. Nothing visible. SafeArea wrapping.
- t=800ms: Line 1 fades in (400ms FadeTransition). Use `AppLocalizations.of(context)!.anonymousIntentLine1`. Style: Montserrat (via GoogleFonts.montserrat), 22px, `MintColors.textPrimary`, fontWeight w500, letterSpacing -0.3.
- t=3500ms: Line 2 fades in (400ms). `anonymousIntentLine2`. Same font, slightly smaller 20px, `MintColors.textSecondary`.
- t=6000ms: 6 pills appear staggered 200ms apart (each fades + slides up slightly over 300ms). Each pill is a tappable container with rounded corners (borderRadius 24), subtle border (`MintColors.lightBorder`), horizontal padding 20, vertical padding 14. Text: Inter 15px, `MintColors.textPrimary`. Background: `MintColors.craie`.
- t=8000ms: Text field fades in (400ms). Use `anonymousIntentFreeTextHint` as hintText.

**Layout:**
- Column centered vertically with `MainAxisAlignment.center`
- Wrap in SingleChildScrollView for small screens
- Lines: left-aligned, horizontal padding 32
- Pills: Wrap widget with spacing 10/runSpacing 10, horizontal padding 24. Each pill uses IntrinsicWidth so it sizes to content.
- Text field: at bottom, horizontal padding 32. Styled minimally — underline only, no filled background. `TextInputAction.send`. Submit on enter.

**Interaction:**
- Pill tap: `context.go('/coach/chat?prompt=${Uri.encodeComponent(pillText)}')` where pillText is the localized pill string.
- Text field submit: same navigation with user's text. Guard against empty text.
- Use `context.go` (not `context.push`) so back button doesn't return here after entering chat.

**Pill texts** (from AppLocalizations):
```dart
final l10n = AppLocalizations.of(context)!;
final pills = [
  l10n.anonymousIntentPill1,
  l10n.anonymousIntentPill2,
  l10n.anonymousIntentPill3,
  l10n.anonymousIntentPill4,
  l10n.anonymousIntentPill5,
  l10n.anonymousIntentPill6,
];
```

**AnimationControllers** (dispose all in dispose()):
- `_line1Controller` (duration 400ms, starts at t=800ms)
- `_line2Controller` (duration 400ms, starts at t=3500ms)
- `_pillControllers` — List<AnimationController> of 6 (each 300ms, staggered from t=6000ms + index*200ms)
- `_textFieldController` (duration 400ms, starts at t=8000ms)

Use `_startSequence()` called from `initState()` via `WidgetsBinding.instance.addPostFrameCallback`. Each delayed start: `Future.delayed(Duration(milliseconds: X), () { if (mounted) controller.forward(); })`.

**Accessibility:**
- Pills: wrap in Semantics with label = pill text
- Text field: standard TextField semantics
- Lines: default Text semantics sufficient

**Do NOT:**
- Add any logo, app name, or branding
- Add any login/register buttons
- Add any skip/dismiss functionality
- Import or show MintShell/BottomNavigationBar
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter analyze lib/screens/anonymous/anonymous_intent_screen.dart 2>&1 | tail -5</automated>
  </verify>
  <done>File exists, compiles with zero analyzer errors. Has 4+ AnimationControllers, 6 pill widgets from i18n, text field, and GoRouter navigation to /coach/chat with prompt param.</done>
</task>

<task type="auto">
  <name>Task 3: Wire route and conditional routing for unauthenticated users</name>
  <files>apps/mobile/lib/app.dart</files>
  <action>
**Import** the new screen at top of app.dart:
```dart
import 'package:mint_mobile/screens/anonymous/anonymous_intent_screen.dart';
```

**Replace the '/' route** (line ~201-205) to conditionally show AnonymousIntentScreen for unauthenticated users and LandingScreen for authenticated users:
```dart
ScopedGoRoute(
  path: '/',
  scope: RouteScope.public,
  builder: (context, state) {
    final isLoggedIn = context.read<AuthProvider>().isLoggedIn;
    if (isLoggedIn) {
      // Authenticated: redirect to shell
      return const LandingScreen();
    }
    return const AnonymousIntentScreen();
  },
),
```

This keeps '/' as RouteScope.public. Unauthenticated users see the intent screen (full-screen, outside shell). Authenticated users see LandingScreen (which is also the /home shell tab). The shell (StatefulShellRoute) at '/home' remains untouched — it only appears for authenticated users who navigate there.

**Cross-fade transition**: Add a `pageBuilder` instead of `builder` to get a fade transition when navigating from intent screen to coach chat. Actually, since GoRouter handles transitions at the route level and the coach chat is inside the shell, the default transition will work. The "cross-fade" feel comes from the warm-white-to-white background shift naturally. No custom transition needed — the standard MaterialPage transition is clean enough.

**Verify the `/coach/chat` route** inside StatefulShellBranch (Tab 1) already accepts `?prompt=` query param and passes it as `initialPrompt` to CoachChatScreen — this is confirmed (line 258). No changes needed there.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter analyze lib/app.dart 2>&1 | tail -5</automated>
  </verify>
  <done>Route '/' shows AnonymousIntentScreen for unauthenticated users. Import added. flutter analyze passes with zero errors on app.dart.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| pill text -> coach chat | User intent pill text passed as URL query param to coach |
| free text -> coach chat | User free-text input passed as URL query param to coach |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-quick-01 | Injection | free text input -> URL param | mitigate | URI.encodeComponent on all user input before passing as query param. Coach chat already sanitizes initialPrompt server-side via ComplianceGuard. |
| T-quick-02 | Information Disclosure | anonymous screen | accept | Screen shows no user data — purely static content + user input. No PII exposed. |
</threat_model>

<verification>
1. `cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter analyze` — zero errors
2. `cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter gen-l10n` — succeeds
3. Manual: open app unauthenticated — see warm white screen, text sequence, pills, text field
4. Manual: tap pill — navigates to coach chat with pill text as prompt
5. Manual: type text + submit — navigates to coach chat with typed text
</verification>

<success_criteria>
- AnonymousIntentScreen renders at '/' for unauthenticated users with full animation sequence
- 6 felt-state pills appear staggered, each navigates to /coach/chat?prompt=...
- Free text field submits to same destination
- All 9 strings in 6 ARB files with cultural adaptations (not literal translations)
- MintColors.warmWhite = #FAF8F5 exists
- Zero flutter analyze errors
- Shell tabs NOT visible on this screen
</success_criteria>

<output>
After completion, create `.planning/quick/260412-kue-implement-first-anonymous-intent-screen-/260412-kue-SUMMARY.md`
</output>
