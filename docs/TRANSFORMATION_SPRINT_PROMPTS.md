# Sprint de Transformation — Coach proactif + UX wow

> **⚠️ LEGACY NOTE (2026-04-05):** Ce document utilise "chiffre choc" comme legacy term.
> Concept canonique : **"premier éclairage"** (voir `docs/MINT_IDENTITY.md`).
>
> Ce document contient les prompts pour transformer MINT d'un "outil éducatif passif"
> en un "coach financier proactif qui fait waouh".
>
> Basé sur les findings W16 (Catherine, PM brutal, logic gaps).
>
> 6 prompts, 3 vagues.

---

## PROMPT 1 — Coach proactif : Cap du Jour → message d'ouverture (CRITIQUE)

```
Tu es un ingénieur full-stack senior. Tu câbles le CapEngine au coach chat
pour que le coach PARLE EN PREMIER avec un message personnalisé et proactif.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/transform-proactive-coach
- Run flutter analyze + flutter test AVANT et APRÈS

## LE PROBLÈME
Aujourd'hui le coach ATTEND que l'utilisateur parle. Il ne dit jamais
"j'ai analysé tes données et voici ce que j'en pense". Le CapEngine
identifie la priorité #1 mais elle est affichée sur le PulseScreen
en tant que carte statique — pas dans le chat comme un message vivant.

## LE FIX

### 1. Quand une NOUVELLE conversation coach s'ouvre

File: apps/mobile/lib/screens/coach/coach_chat_screen.dart

Dans initState() ou _initializeChat(), APRÈS le chargement du profil
et AVANT que l'utilisateur ne tape quoi que ce soit :

```dart
Future<void> _generateProactiveOpener() async {
  if (_messages.isNotEmpty) return; // Pas sur une conversation existante
  if (_profile == null) return;

  // 1. Charger le Cap du Jour
  final mintState = context.read<MintStateProvider>().state;
  final cap = mintState?.cap;
  if (cap == null) return;

  // 2. Construire un contexte d'ouverture pour le coach
  final openerContext = {
    'capId': cap.id,
    'capHeadline': cap.headline,
    'capWhyNow': cap.whyNow,
    'capImpact': cap.estimatedImpact,
    'userName': _profile!.firstName ?? '',
    'userAge': _profile!.age,
    'cashLevel': _cashLevel,
  };

  // 3. Envoyer au coach comme un "system message" interne
  // Le coach reçoit le cap comme contexte et GÉNÈRE un message d'ouverture
  try {
    final opener = await _orchestrator.generateOpener(
      profile: _profile!,
      capContext: openerContext,
      cashLevel: _cashLevel,
    );

    if (opener != null && opener.isNotEmpty && mounted) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: opener,
          tier: ChatTier.slm, // ou byok selon disponibilité
        ));
      });
    }
  } catch (e) {
    debugPrint('[Coach] Proactive opener failed: $e');
    // Fallback silencieux — le chat reste vide, l'utilisateur parle en premier
  }
}
```

### 2. Implémenter generateOpener() dans l'orchestrateur

File: apps/mobile/lib/services/coach/coach_orchestrator.dart

```dart
/// Generate a proactive opening message based on the Cap du Jour.
/// The coach analyzes the user's situation and speaks FIRST.
Future<String?> generateOpener({
  required CoachProfile profile,
  required Map<String, dynamic> capContext,
  int cashLevel = 3,
}) async {
  final capHeadline = capContext['capHeadline'] ?? '';
  final capWhyNow = capContext['capWhyNow'] ?? '';
  final userName = capContext['userName'] ?? '';
  final userAge = capContext['userAge'] ?? '';

  // Build a special opener prompt
  final openerPrompt = '''
Tu ouvres une nouvelle conversation avec ${userName.isNotEmpty ? userName : "l'utilisateur"}.
Tu as analysé son profil et identifié une priorité :

PRIORITÉ : $capHeadline
POURQUOI MAINTENANT : $capWhyNow

Génère UN message d'ouverture (2-4 phrases max) qui :
1. Mentionne le prénom si disponible
2. Va droit au sujet avec le ton correspondant à l'intensité $cashLevel/5
3. Pose UNE question ouverte à la fin pour lancer la conversation
4. NE commence PAS par "Bonjour" ou "Salut" — commence par le sujet

Exemples de ton (intensité $cashLevel) :
- Intensité 3 : "Catherine, ton 3a est vide cette année. Il reste 47 jours. On en parle ?"
- Intensité 5 : "Catherine. 47 jours, 0 franc versé sur ton 3a. Chaque jour qui passe, c'est du fisc en cadeau. On fait quoi ?"
''';

  // Use the same LLM pipeline as regular chat
  final response = await generateChat(
    userMessage: openerPrompt,
    profile: profile,
    history: const [], // No history — first message
    isOpener: true, // Flag pour le system prompt
  );

  return response?.message;
}
```

### 3. Adapter le system prompt pour les openers

File: services/backend/app/services/coach/claude_coach_service.py

Dans build_system_prompt(), si le message est un opener (pas une question
utilisateur), ajouter une instruction spéciale :

```python
if is_opener:
    base += """

## MODE PROACTIF (opener)
Tu PARLES EN PREMIER. L'utilisateur n'a rien dit encore.
Tu as analysé son profil et identifié une priorité.
Ton message doit :
- Être court (2-4 phrases)
- Aller droit au sujet (pas de "bonjour comment ça va")
- Mentionner un CHIFFRE concret de son profil
- Poser UNE question ouverte pour lancer la conversation
- Respecter l'intensité choisie ({cash_level}/5)
"""
```

### 4. Ne PAS générer d'opener si le cap n'a pas changé

Pour éviter le même message à chaque ouverture, stocker le dernier
cap utilisé pour l'opener :

```dart
final prefs = await SharedPreferences.getInstance();
final lastOpenerCapId = prefs.getString('_last_opener_cap_id');
if (lastOpenerCapId == cap.id) return; // Même cap, pas de nouvel opener
await prefs.setString('_last_opener_cap_id', cap.id);
```

## VÉRIFICATION
1. Ouvrir une nouvelle conversation → le coach parle EN PREMIER
2. Le message mentionne un chiffre du profil (pas générique)
3. Le message respecte l'intensité choisie
4. Fermer et rouvrir avec le même cap → pas de doublon
5. flutter test — tous passent
6. git commit: "feat(coach): proactive opener from Cap du Jour"
```

---

## PROMPT 2 — Chiffre choc en 2 taps (conversion funnel)

```
Tu es un ingénieur Flutter UX senior. Tu transformes l'onboarding
pour montrer la valeur en 2 taps au lieu de 8.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/transform-2tap-chiffre-choc
- Run flutter analyze + flutter test + flutter gen-l10n AVANT et APRÈS

## LE PROBLÈME
Aujourd'hui : Landing → Commencer → Consent → Form (4 champs) → Submit
→ Chiffre choc = 6+ taps avant la première valeur.
Cible : Landing → 2 champs inline → Chiffre choc = 2 taps.

## LE FIX

### 1. Modifier le landing screen

File: apps/mobile/lib/screens/landing_screen.dart

Au lieu du bouton "Commencer" qui mène à l'onboarding complet,
ajouter 2 champs inline directement sur le landing :

```dart
// Section "Ton chiffre en 30 secondes"
Column(
  children: [
    Text(S.of(context)!.landingQuickCalcTitle,
      style: MintTextStyles.titleMedium(),
    ), // "Ton chiffre en 30 secondes"

    const SizedBox(height: 16),

    // Champ 1 : Année de naissance (CupertinoPicker compact)
    MintPickerTile(
      label: S.of(context)!.landingBirthYear,
      value: _birthYear?.toString() ?? '',
      onTap: () => _showBirthYearPicker(),
    ),

    const SizedBox(height: 12),

    // Champ 2 : Salaire brut annuel (presets rapides)
    Wrap(
      spacing: 8,
      children: [50, 70, 90, 120, 150].map((k) =>
        ChoiceChip(
          label: Text('${k}k'),
          selected: _salary == k * 1000,
          onSelected: (v) => setState(() => _salary = k * 1000),
        ),
      ).toList(),
    ),

    const SizedBox(height: 24),

    // Bouton : Calculer
    FilledButton(
      onPressed: _birthYear != null && _salary != null
          ? () => _showInstantChiffreChoc()
          : null,
      child: Text(S.of(context)!.landingCalculate), // "Voir mon chiffre"
    ),
  ],
)
```

### 2. Calcul instantané SANS compte

```dart
void _showInstantChiffreChoc() {
  final age = DateTime.now().year - _birthYear!;
  final monthlyRente = AvsCalculator.computeMonthlyRente(
    currentAge: age,
    retirementAge: 65,
    grossAnnualSalary: _salary!.toDouble(),
  );
  // LPP estimation simplifiée
  final lppMonthly = LppCalculator.estimateMonthlyRente(
    currentAge: age,
    grossAnnualSalary: _salary!.toDouble(),
  );
  final totalMonthly = monthlyRente + lppMonthly;
  final currentMonthly = _salary! / 12 * 0.85; // Net estimé
  final replacementRate = totalMonthly / currentMonthly;

  // Naviguer vers un chiffre choc SIMPLIFIÉ (pas l'onboarding complet)
  context.push('/chiffre-choc-instant', extra: {
    'totalMonthly': totalMonthly,
    'currentMonthly': currentMonthly,
    'replacementRate': replacementRate,
    'age': age,
    'salary': _salary,
  });
}
```

### 3. Écran chiffre choc instant (NOUVEAU, simplifié)

File: apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart (NOUVEAU)

Un écran minimaliste :
- Le big number animé (comme le chiffre choc existant)
- Un contexte : "C'est X% de ton salaire actuel. La moyenne suisse est 68%."
- DEUX boutons :
  - "Créer un compte pour aller plus loin" → signup → onboarding complet
  - "Refaire avec d'autres chiffres" → retour landing

PAS de consent dialog, PAS de stockage, PAS de profil créé.
C'est un calcul ÉPHÉMÈRE — si l'utilisateur veut sauvegarder, il crée un compte.

### 4. Route GoRouter

File: apps/mobile/lib/app.dart
Ajouter la route `/chiffre-choc-instant` dans les publicPrefixes (pas d'auth requise).

### 5. Clés i18n

Ajouter dans les 6 ARB files :
- landingQuickCalcTitle: "Ton chiffre en 30 secondes"
- landingBirthYear: "Année de naissance"
- landingCalculate: "Voir mon chiffre"
- instantChocContext: "{rate}% de ton salaire actuel à la retraite"
- instantChocAverage: "La moyenne suisse est de 68%."
- instantChocSignup: "Créer un compte pour aller plus loin"
- instantChocRetry: "Refaire avec d'autres chiffres"

## VÉRIFICATION
1. Landing screen → 2 champs visibles (birth year + salary)
2. Remplir + tapper "Voir mon chiffre" → chiffre choc en <1 seconde
3. PAS de compte créé, PAS de données stockées
4. flutter analyze — 0 errors
5. flutter test — tous passent
6. git commit: "feat(onboarding): 2-tap chiffre choc on landing (no account required)"
```

---

## PROMPT 3 — Action engine : chaque écran dit "fais ÇA"

```
Tu es un ingénieur Flutter UX senior. Tu ajoutes un CTA contextualisé
à chaque écran financier.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/transform-action-engine
- Run flutter analyze + flutter test AVANT et APRÈS

## LE PROBLÈME
Les dashboards montrent des chiffres sans dire quoi faire.
"Taux de remplacement : 62%" → et alors ?

## LE FIX

### 1. Créer un ActionInsightWidget réutilisable

File: apps/mobile/lib/widgets/action_insight_widget.dart (NOUVEAU)

```dart
/// Widget who answers "so what?" for any financial number.
/// Shows: context line + action CTA + estimated impact.
class ActionInsightWidget extends StatelessWidget {
  final String contextLine; // "C'est en dessous de la moyenne (68%)"
  final String actionLabel; // "Verse 500 CHF/mois sur ton 3a"
  final String? impactLabel; // "+9% en 16 ans"
  final String? route; // "/pilier-3a"
  final IconData icon;

  // ... constructor ...

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.bleuAir.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: MintColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(contextLine,
                style: MintTextStyles.bodySmall())),
            ],
          ),
          if (actionLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: route != null ? () => context.push(route!) : null,
              child: Row(
                children: [
                  Text(actionLabel,
                    style: MintTextStyles.bodySmall().copyWith(
                      color: MintColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
                  if (impactLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.success.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(impactLabel!,
                        style: MintTextStyles.caption().copyWith(
                          color: MintColors.success)),
                    ),
                  ],
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios,
                    size: 14, color: MintColors.primary),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

### 2. Intégrer sur le retirement dashboard

File: apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart

Après le hero number (replacement rate), ajouter :

```dart
ActionInsightWidget(
  contextLine: replacementRate >= 0.8
      ? S.of(context)!.retirementContextGood // "Bon niveau, au-dessus de 80%"
      : replacementRate >= 0.6
          ? S.of(context)!.retirementContextAverage // "Moyenne suisse. Optimisable."
          : S.of(context)!.retirementContextLow, // "En dessous. Agissons."
  actionLabel: cap?.headline ?? S.of(context)!.retirementDefaultAction,
  impactLabel: cap?.estimatedImpact,
  route: cap?.route ?? '/pilier-3a',
  icon: Icons.trending_up,
),
```

### 3. Intégrer sur le pulse screen

File: apps/mobile/lib/screens/pulse/pulse_screen.dart

Même pattern — après le dominant number, ajouter le ActionInsightWidget
avec le cap du jour comme source.

### 4. Clés i18n

- retirementContextGood / retirementContextAverage / retirementContextLow
- retirementDefaultAction: "Simule ton 3a pour voir l'impact"
- pulseContextAction: "Voici ta priorité du jour"

## VÉRIFICATION
1. Retirement dashboard → après le chiffre, il y a un contexte + action
2. Pulse screen → cap du jour visible avec CTA
3. flutter test — tous passent
4. git commit: "feat(ux): action insight widget on retirement + pulse dashboards"
```

---

## PROMPT 4 — Day-1 hook : progress bar + notification J+1

```
Tu es un ingénieur Flutter + backend senior.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/transform-day1-hook
- Run flutter analyze + flutter test + pytest tests/ -q AVANT et APRÈS

## LE PROBLÈME
Après l'onboarding, rien ne ramène l'utilisateur demain.
Pas de progress bar, pas de notification J+1.

## FIX 1 : Progress bar "Profil X% complet"

File: apps/mobile/lib/screens/pulse/pulse_screen.dart

Ajouter un widget progress en haut du pulse screen :

```dart
// Calculer la complétude
final fields = {
  'age': profile.birthYear != null,
  'salary': profile.salaireBrutMensuel > 0,
  'canton': profile.canton.isNotEmpty,
  'lpp': (profile.prevoyance.avoirLppTotal ?? 0) > 0,
  '3a': (profile.prevoyance.totalEpargne3a ?? 0) > 0,
  'couple': profile.conjoint != null,
  'document': documentCount > 0,
  'budget': hasBudgetData,
};
final completeness = fields.values.where((v) => v).length / fields.length;
final nextMissing = fields.entries.firstWhere((e) => !e.value, orElse: () => fields.entries.first);

// Widget
if (completeness < 1.0) {
  LinearProgressIndicator(value: completeness, color: MintColors.primary);
  Text('Profil ${(completeness * 100).toInt()}% complet');
  Text('Prochaine étape : ${_labelForField(nextMissing.key)}');
}
```

## FIX 2 : Notification J+1 personnalisée

File: apps/mobile/lib/services/notification_service.dart

Ajouter une notification "day after signup" :

```dart
static Future<void> scheduleDay1Notification({
  required double taxSaving3a,
  required String canton,
}) async {
  if (taxSaving3a <= 0) return;
  final tomorrow = DateTime.now().add(const Duration(hours: 24));

  await _scheduleNotification(
    id: 9000, // Unique ID for day-1
    title: S.current.day1NotificationTitle, // "Tu savais ?"
    body: S.current.day1NotificationBody(formatChf(taxSaving3a)),
    // "Tu laisses CHF X au fisc chaque année. On en parle ?"
    scheduledDate: tomorrow,
    payload: '/coach/chat?prompt=parle-moi+de+mon+3a',
  );
}
```

Appeler après l'onboarding :
```dart
// Dans smart_onboarding_screen.dart, après _saveProfile() :
final taxSaving = TaxCalculator.estimate3aTaxSaving(
  grossAnnualSalary: salary,
  canton: canton,
);
NotificationService.scheduleDay1Notification(
  taxSaving3a: taxSaving,
  canton: canton,
);
```

## FIX 3 : Notification tape → ouvre le coach avec un prompt

La notification a un payload `/coach/chat?prompt=parle-moi+de+mon+3a`.
Quand l'utilisateur tape → le coach chat s'ouvre avec ce prompt pré-rempli
→ le coach proactif (prompt 1) répond immédiatement.

## VÉRIFICATION
1. Après onboarding → pulse screen montre "Profil 45% complet"
2. J+1 → notification reçue avec montant personnalisé
3. Tap notification → coach chat avec message sur le 3a
4. flutter test — tous passent
5. git commit: "feat(engagement): progress bar + J+1 notification + coach deep link"
```

---

## PROMPT 5 — Couple mode visible avant paywall

```
Tu es un ingénieur Flutter UX senior.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/transform-couple-visible
- Run flutter analyze + flutter test AVANT et APRÈS

## LE PROBLÈME
Le couple mode est invisible jusqu'après le paywall. L'utilisateur
découvre que son cas d'usage principal est payant APRÈS avoir créé
un compte.

## LE FIX

### 1. Preview couple sur le landing

File: apps/mobile/lib/screens/landing_screen.dart

Ajouter une section "En couple ?" sur le landing :
```dart
// Section couple teaser
Container(
  padding: EdgeInsets.all(MintSpacing.lg),
  child: Column(
    children: [
      Text(S.of(context)!.landingCoupleTitle),
      // "En couple ? MINT optimise à deux."
      Text(S.of(context)!.landingCoupleSubtitle),
      // "Pénalité mariage, coordination AVS, rachats LPP croisés."
      OutlinedButton(
        onPressed: () => context.push('/auth/register?intent=couple'),
        child: Text(S.of(context)!.landingCoupleAction),
        // "Découvrir le mode couple"
      ),
    ],
  ),
)
```

### 2. Preview gratuite avant le paywall

Quand l'utilisateur (non-premium) tape "Découvrir le mode couple" :
- Montrer un écran d'aperçu avec des exemples :
  - "Pénalité mariage : un couple gagnant 120k+80k paie CHF X de plus"
  - "AVS couple cap : vos rentes sont plafonnées à 3'780 CHF/mois"
  - "Rachats croisés : qui rachète en premier fait économiser CHF Y"
- EN BAS : "Débloquer le mode couple — Premium à CHF Z/mois"

L'utilisateur voit la VALEUR avant de payer.

## VÉRIFICATION
1. Landing → section couple visible
2. Tap → preview avec exemples concrets
3. Paywall visible avec prix
4. flutter test — tous passent
5. git commit: "feat(couple): visible preview before paywall on landing"
```

---

## PROMPT 6 — Jargon glossaire intégré

```
Tu es un ingénieur Flutter senior.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/transform-glossary
- Run flutter analyze + flutter test + flutter gen-l10n AVANT et APRÈS

## LE PROBLÈME
Catherine ne sait pas ce que veulent dire LPP, AVS, 3a, RAMD, taux de
conversion, rachat, lacune. Le jargon est partout sans explication.

## LE FIX

### 1. Créer un service de glossaire

File: apps/mobile/lib/services/glossary_service.dart (NOUVEAU)

```dart
class GlossaryService {
  static const Map<String, String> _terms = {
    'LPP': 'Prévoyance professionnelle — l\'argent mis de côté par ton employeur pour ta retraite.',
    'AVS': 'Assurance vieillesse et survivants — la rente de base que tout le monde reçoit.',
    '3a': 'Pilier 3a — ton épargne retraite personnelle, déductible des impôts.',
    'RAMD': 'Revenu annuel moyen déterminant — la base de calcul de ta rente AVS.',
    'Taux de conversion': 'Le pourcentage qui transforme ton capital LPP en rente mensuelle.',
    'Rachat LPP': 'Versement volontaire dans ta caisse de pension — déductible des impôts.',
    'Lacune': 'Année sans cotisation AVS — réduit ta rente future.',
    'Taux de remplacement': 'La part de ton salaire actuel que tu garderas à la retraite.',
    'Rente': 'Revenu mensuel versé à la retraite (par l\'AVS ou la LPP).',
    'Capital': 'Somme d\'argent retirée en une fois à la retraite (alternative à la rente).',
  };

  static String? explain(String term) => _terms[term];
  static bool hasTerm(String term) => _terms.containsKey(term);
}
```

### 2. Créer un widget GlossaryTerm

File: apps/mobile/lib/widgets/glossary_term.dart (NOUVEAU)

```dart
class GlossaryTerm extends StatelessWidget {
  final String term; // "LPP"
  final String? suffix; // Optional text after the term

  @override
  Widget build(BuildContext context) {
    final explanation = GlossaryService.explain(term);
    if (explanation == null) return Text(term);

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(term, style: MintTextStyles.titleMedium()),
              const SizedBox(height: 12),
              Text(explanation, style: MintTextStyles.bodyMedium()),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      child: Text.rich(TextSpan(
        children: [
          TextSpan(
            text: term,
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              color: MintColors.primary,
            ),
          ),
          if (suffix != null) TextSpan(text: suffix),
        ],
      )),
    );
  }
}
```

### 3. Utiliser sur les écrans principaux

Remplacer les Text() statiques contenant du jargon par GlossaryTerm :
- Retirement dashboard : "Rente AVS + LPP" → GlossaryTerm("AVS") + " + " + GlossaryTerm("LPP")
- Chiffre choc : "Taux de remplacement" → GlossaryTerm("Taux de remplacement")
- Onboarding calibration : "avoir LPP", "taux de conversion", "3a"

NE PAS tout remplacer — seulement les 10 termes les plus fréquents sur
les écrans que Catherine voit en premier (onboarding, chiffre choc,
retirement dashboard, coach chat).

## VÉRIFICATION
1. Retirement dashboard → "LPP" est souligné en pointillé
2. Tap sur "LPP" → bottom sheet avec explication
3. flutter gen-l10n — 0 errors
4. flutter test — tous passent
5. git commit: "feat(glossary): tap-to-explain jargon on key screens"
```

---

## ORCHESTRATION

```
Tu es un orchestrateur de sprint. Ta mission : lancer les 6 prompts
du fichier docs/TRANSFORMATION_SPRINT_PROMPTS.md.

## RÈGLE GIT CRITIQUE (NON-NÉGOCIABLE)

NE JAMAIS utiliser isolation: "worktree" pour les agents.
Les worktrees créent des branches worktree-agent-* où les commits se PERDENT.

Pour CHAQUE agent :
1. L'agent travaille DIRECTEMENT dans le repo principal (PAS de worktree)
2. L'agent crée sa feature branch : git checkout -b feature/xxx
3. L'agent commite sur CETTE branche (pas worktree-agent-*)
4. Vérifier AVANT merge : git log feature/xxx --oneline → les commits sont là ?

Si un agent a utilisé un worktree par erreur :
1. NE PAS supprimer le worktree avant d'avoir récupéré les commits
2. git log worktree-agent-xxx --oneline → identifier les commits
3. git cherry-pick <hash> sur dev → récupérer le travail
4. ENSUITE supprimer : git worktree remove ... --force

## RÈGLE CÂBLAGE (NON-NÉGOCIABLE)

Après CHAQUE fix, l'agent DOIT tracer le flux end-to-end :
User tap → [composant 1] → [composant 2] → ... → résultat affiché
Si UN maillon manque → le fix n'est PAS terminé.
NE JAMAIS marquer "DONE" sans avoir vérifié que le fil est CONNECTÉ.

## PLAN D'EXÉCUTION

### VAGUE 1 — Coach proactif + Day-1 hook (SÉQUENTIEL)
| Étape | Prompt | Branch |
|-------|--------|--------|
| 1a | P1 (Coach proactif opener) | feature/transform-proactive-coach |
| 1b | P4 (Day-1 hook — progress + notif) | feature/transform-day1-hook |

P4 dépend de P1 (le J+1 notification deep link vers le coach proactif).
Merger P1 → dev, puis lancer P4.

### VAGUE 2 — UX transformation (3 agents EN PARALLÈLE)
| Agent | Prompt | Branch |
|-------|--------|--------|
| A | P2 (Chiffre choc 2 taps) | feature/transform-2tap-chiffre-choc |
| B | P3 (Action engine) | feature/transform-action-engine |
| C | P6 (Glossaire jargon) | feature/transform-glossary |

Pas de conflit. Merger : C → B → A

### VAGUE 3 — Couple visible (1 agent)
| Agent | Prompt | Branch |
|-------|--------|--------|
| D | P5 (Couple preview) | feature/transform-couple-visible |

Merger D → dev.

### VÉRIFICATION FINALE
1. Nouvelle conversation coach → message proactif basé sur Cap du Jour ✅/❌
2. Landing → 2 champs → chiffre choc SANS compte ✅/❌
3. Retirement dashboard → contexte "c'est bien/moyen" + CTA ✅/❌
4. J+1 → notification personnalisée avec montant ✅/❌
5. Landing → section couple visible ✅/❌
6. Tap "LPP" → bottom sheet explication ✅/❌
7. flutter analyze — 0 errors
8. flutter test — tous passent

## CRITÈRES DE SUCCÈS
- 6/6 branches mergées
- Coach parle EN PREMIER avec données personnalisées
- Chiffre choc en 2 taps (pas 8)
- Chaque écran financier dit "fais ÇA"
- Day-1 notification envoie l'utilisateur vers le coach
- Couple mode visible AVANT le paywall
- Jargon expliqué au tap
```
