---
phase: quick-260412-szs
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - apps/mobile/lib/l10n/app_fr.arb
  - apps/mobile/lib/l10n/app_en.arb
  - apps/mobile/lib/l10n/app_de.arb
  - apps/mobile/lib/l10n/app_it.arb
  - apps/mobile/lib/l10n/app_es.arb
  - apps/mobile/lib/l10n/app_pt.arb
  - apps/mobile/lib/screens/coach/coach_chat_screen.dart
autonomous: true
requirements: []
must_haves:
  truths:
    - "Coach chat shows a random provocative greeting when no messages exist"
    - "Greeting is different each time the screen is opened (random from 20)"
    - "Greeting disappears once user sends first message"
    - "No pills, no buttons, no CTA — just the text and silence"
    - "All 6 languages have culturally adapted greeting texts"
  artifacts:
    - path: "apps/mobile/lib/l10n/app_fr.arb"
      provides: "20 French greeting keys (coachGreetingRandom1-20)"
      contains: "coachGreetingRandom"
    - path: "apps/mobile/lib/screens/coach/coach_chat_screen.dart"
      provides: "Random greeting display replacing felt-state pills"
      contains: "_greetingIndex"
  key_links:
    - from: "coach_chat_screen.dart"
      to: "app_fr.arb"
      via: "S.of(context)! localization keys"
      pattern: "coachGreetingRandom"
---

<objective>
Add 20 random provocative coach greeting messages with full i18n support, and replace the felt-state pills in coach_chat_screen.dart with a single random greeting text displayed silently.

Purpose: The greeting sets MINT's tone — sharp, provocative, Swiss-specific financial truths that make the user think. No CTA, no buttons, just one powerful sentence and silence.
Output: 20 i18n keys in 6 languages + coach chat screen showing random greeting instead of pills.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@apps/mobile/lib/l10n/app_fr.arb
@apps/mobile/lib/screens/coach/coach_chat_screen.dart

Key localization pattern: `S.of(context)!.keyName` (NOT AppLocalizations)
Colors: `MintColors.*` from `lib/theme/colors.dart`
Fonts: `GoogleFonts.montserrat` for headings
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add 20 greeting keys to all 6 ARB files + gen-l10n</name>
  <files>
    apps/mobile/lib/l10n/app_fr.arb
    apps/mobile/lib/l10n/app_en.arb
    apps/mobile/lib/l10n/app_de.arb
    apps/mobile/lib/l10n/app_it.arb
    apps/mobile/lib/l10n/app_es.arb
    apps/mobile/lib/l10n/app_pt.arb
  </files>
  <action>
Add 20 keys (`coachGreetingRandom1` through `coachGreetingRandom20`) to each of the 6 ARB files. Add keys at END of each file (before final `}`). Each key gets @metadata: `{"description": "Coach chat random greeting message N"}`.

**FRENCH (app_fr.arb) — EXACT texts, do NOT modify, accents mandatory:**
1. "Ton 3a, c'est qui qui l'a choisi\u00a0? Toi ou \u00ab\u00a0le gars\u00a0\u00bb\u00a0?"
2. "En Suisse on parle pas d'argent. On en perd en silence."
3. "Le gars qui t'a vendu ton 3a a touch\u00e9 sa commission la premi\u00e8re ann\u00e9e. Toi, t'attends encore ton rendement."
4. "Ton banquier te conna\u00eet mieux que toi. C'est pas un compliment."
5. "Tout le monde te dit d'acheter. Ton banquier, tes parents, ton beau-fr\u00e8re. T'as demand\u00e9 \u00e0 quelqu'un qui vend rien\u00a0?"
6. "\u00c0 25\u00a0ans, tu cotises d\u00e9j\u00e0 pour ta retraite. \u00c0 25\u00a0ans, tu sais pas que tu cotises pour ta retraite."
7. "Tu g\u00e8res pas tes finances. Tu les \u00e9vites. Y'a une diff\u00e9rence."
8. "Tu sais combien tu vas toucher \u00e0 la retraite\u00a0? Personne sait."
9. "Si ton salaire s'arr\u00eate demain \u2014 tu sais ce qui se passe\u00a0?"
10. "Ton assureur voit un morceau. Ton banquier aussi. Ta fiduciaire aussi. L'image compl\u00e8te, personne."
11. "T'as sign\u00e9 combien de trucs que t'as pas lus\u00a0?"
12. "T'as d\u00e9j\u00e0 ouvert ton certificat de pr\u00e9voyance\u00a0? Vraiment ouvert\u00a0?"
13. "Ton \u00e9pargne dort. Tu sais combien \u00e7a te co\u00fbte, dormir\u00a0?"
14. "Le syst\u00e8me de retraite suisse est excellent. C'est juste que personne t'a fil\u00e9 le mode d'emploi."
15. "Tu changes de job, tu regardes le salaire. Tu regardes jamais la caisse de pension."
16. "Tu retires ton 3a et ton 2e\u00a0pilier la m\u00eame ann\u00e9e\u00a0? L'imp\u00f4t explose. Tu les \u00e9tales\u00a0? Il fond. M\u00eame argent. Juste le timing."
17. "Tu pourrais racheter des ann\u00e9es dans ton 2e\u00a0pilier et payer des milliers de francs d'imp\u00f4ts en moins. Mais faudrait ouvrir le certificat."
18. "Amortissement direct ou indirect\u00a0? Si tu sais pas la diff\u00e9rence, tu paies plus d'imp\u00f4ts que n\u00e9cessaire. Depuis le d\u00e9but."
19. "T'es ind\u00e9pendant. Plus personne cotise pour toi. Tout est \u00e0 construire. T'as commenc\u00e9\u00a0?"
20. "Pour acheter, tu mets une partie de ton 2e\u00a0pilier dans les murs. Ton futur toi \u00e0 la retraite, il en pense quoi\u00a0?"

IMPORTANT: Use `\u00a0` (non-breaking space) before `?`, `!`, `:`, `;` per French typography rules. The texts above already include them.

**ENGLISH (app_en.arb) — culturally adapted, same provocative tone, Swiss context:**
Adapt each message to English while keeping the sharp, questioning tone. Swiss-specific references (3a, 2nd pillar, LPP, pension certificate) stay as-is since the app targets Swiss residents. Examples:
- 1: "Your 3a — who picked it? You, or 'that guy'?"
- 2: "In Switzerland, we don't talk about money. We lose it in silence."
- etc. (all 20, culturally adapted)

**GERMAN (app_de.arb) — Swiss German adapted, du-form, same sharpness:**
Swiss German cultural tone. Use "du" form. Keep Swiss references. Examples:
- 1: "Dis 3a — wer hets usegsuecht? Du oder 'de Typ'?"
- 2: "In der Schwiz redet mer nid \u00fcber Geld. Mer verliert's still."
- etc. (all 20)

**ITALIAN (app_it.arb) — Ticino adapted, tu-form:**
- 1: "Il tuo 3a, chi l'ha scelto? Tu o 'quel tizio'?"
- 2: "In Svizzera non si parla di soldi. Li si perde in silenzio."
- etc. (all 20)

**SPANISH (app_es.arb) — Spanish adapted, tu-form:**
- 1: "\u00bfTu 3a, qui\u00e9n lo eligi\u00f3? \u00bfT\u00fa o 'el tipo'?"
- 2: "En Suiza no se habla de dinero. Se pierde en silencio."
- etc. (all 20)

**PORTUGUESE (app_pt.arb) — Portuguese adapted, tu-form:**
- 1: "O teu 3a, quem escolheu? Tu ou 'o tipo'?"
- 2: "Na Su\u00ed\u00e7a n\u00e3o se fala de dinheiro. Perde-se em sil\u00eancio."
- etc. (all 20)

After adding all keys, run: `cd apps/mobile && flutter gen-l10n`
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter gen-l10n 2>&1 | tail -5 && grep -c "coachGreetingRandom" lib/l10n/app_fr.arb</automated>
  </verify>
  <done>All 6 ARB files contain coachGreetingRandom1-20 with @metadata. flutter gen-l10n succeeds. grep count shows 40 lines (20 keys + 20 @metadata) in app_fr.arb.</done>
</task>

<task type="auto">
  <name>Task 2: Replace felt-state pills with random greeting in coach_chat_screen.dart</name>
  <files>apps/mobile/lib/screens/coach/coach_chat_screen.dart</files>
  <action>
Three changes in coach_chat_screen.dart:

**A. Add field + import:**
- Add `import 'dart:math';` at the top (if not already present)
- Add field in `_CoachChatScreenState` (around line 134, after existing fields):
  ```dart
  /// Random greeting index — picked once per screen open.
  final int _greetingIndex = Random().nextInt(20);
  ```

**B. Replace `_buildFeltStatePills()` with `_buildRandomGreeting()`:**
Delete the entire `_buildFeltStatePills()` method (lines ~1470-1508). Replace with:

```dart
Widget _buildRandomGreeting() {
  final s = S.of(context)!;
  final greetings = [
    s.coachGreetingRandom1,  s.coachGreetingRandom2,
    s.coachGreetingRandom3,  s.coachGreetingRandom4,
    s.coachGreetingRandom5,  s.coachGreetingRandom6,
    s.coachGreetingRandom7,  s.coachGreetingRandom8,
    s.coachGreetingRandom9,  s.coachGreetingRandom10,
    s.coachGreetingRandom11, s.coachGreetingRandom12,
    s.coachGreetingRandom13, s.coachGreetingRandom14,
    s.coachGreetingRandom15, s.coachGreetingRandom16,
    s.coachGreetingRandom17, s.coachGreetingRandom18,
    s.coachGreetingRandom19, s.coachGreetingRandom20,
  ];
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
    child: Text(
      greetings[_greetingIndex],
      style: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: MintColors.textPrimary,
        height: 1.5,
      ),
      textAlign: TextAlign.center,
    ),
  );
}
```

**C. Update caller in `_buildSilentOpenerWithTone()` (around lines 1427-1468):**
Change the line:
```dart
final pills = _messages.isEmpty ? _buildFeltStatePills() : const SizedBox.shrink();
```
to:
```dart
final greeting = _messages.isEmpty ? _buildRandomGreeting() : const SizedBox.shrink();
```

And update both Column children lists to use `greeting` instead of `pills`:
```dart
children: [
  opener,
  greeting,
],
```

Make sure `GoogleFonts` import exists (it should already — check top of file). The key behavior: when `_messages.isEmpty`, one random greeting is shown centered. Once the user sends a message, `_messages` is no longer empty and `SizedBox.shrink()` replaces the greeting.

Do NOT remove the `anonymousIntentPill1-6` ARB keys from the ARB files (they may be reused). Only remove their usage from this Dart file.
  </action>
  <verify>
    <automated>cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter analyze lib/screens/coach/coach_chat_screen.dart 2>&1 | tail -10</automated>
  </verify>
  <done>coach_chat_screen.dart compiles with zero analyzer errors. _buildFeltStatePills is gone. _buildRandomGreeting displays one of 20 i18n greetings. No pills, no buttons, no CTA remain in the empty-state view. The greeting index is fixed per screen instantiation (Random in field initializer).</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

No trust boundaries crossed — purely client-side UI change with static i18n strings.

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-quick-01 | I (Info Disclosure) | greeting texts | accept | Texts are educational provocations, contain no user data or secrets |
</threat_model>

<verification>
1. `flutter gen-l10n` succeeds (all 6 ARB files valid JSON with matching keys)
2. `flutter analyze lib/screens/coach/coach_chat_screen.dart` — 0 errors
3. Coach chat screen opens with a single centered text (no pills)
4. Text changes on next screen open (different random index)
5. Text disappears after first message is sent
</verification>

<success_criteria>
- 20 greeting keys exist in all 6 ARB files with @metadata
- coach_chat_screen.dart shows random greeting instead of pills when messages are empty
- Zero analyzer errors
- No felt-state pill code remains in coach_chat_screen.dart
</success_criteria>

<output>
After completion, create `.planning/quick/260412-szs-20-random-coach-greeting-messages-with-i/260412-szs-SUMMARY.md`
</output>
