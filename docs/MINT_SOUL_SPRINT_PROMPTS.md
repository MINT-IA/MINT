# MINT Soul Sprint — Le prompt qui change tout

> **⚠️ LEGACY NOTE (2026-04-05):** Ce document utilise "chiffre choc" comme legacy term.
> Concept canonique : **"premier éclairage"** (voir `docs/MINT_IDENTITY.md`).
>
> Ce n'est pas un sprint technique. C'est le sprint qui donne une ÂME à MINT.
>
> Basé sur : 16 waves d'audit (~500 findings), 4 experts (Swiss strategist,
> Cleo analyst, UX psychologue, Tech architect), et la vision du fondateur.
>
> Les 6 vérités de MINT :
> 1. Le curseur d'intensité résout la crise d'identité
> 2. Le chiffre choc est un moment de vérité, pas un hook
> 3. Le coach attend, il ne parle pas en premier
> 4. Le moment de silence est le moment le plus important
> 5. Transparence radicale sur la privacy
> 6. Tester avec de vrais humains, pas ajouter des features
>
> 7 prompts. 3 vagues. Zéro compromis.

---

## PROMPT 1 — Le moment de silence (L'ÂME de MINT)

```
Tu es un ingénieur Flutter senior ET un designer d'expériences émotionnelles.
Ce prompt est le plus important de tout le projet MINT.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## RÈGLE GIT (NON-NÉGOCIABLE)
NE PAS utiliser isolation: "worktree". Travailler dans le repo principal.
git checkout -b feature/soul-moment-de-silence

## RÈGLE CÂBLAGE (NON-NÉGOCIABLE)
Après le fix, tracer le flux COMPLET :
User tap → chiffre choc → silence → question → champ texte → coach répond
Si UN maillon manque → le fix n'est PAS terminé.

## CE QU'IL FAUT CRÉER

### Le flow émotionnel post-chiffre choc

Aujourd'hui après le big number : 3 boutons, 5 actions, du jargon.
Demain : un SILENCE. Puis une question. Puis une conversation.

File: apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart
(ou le screen qui affiche le résultat du chiffre choc après l'onboarding)

Après l'animation du big number (ex: "4'280 CHF/mois"), REMPLACER
les boutons d'action par cette séquence :

```dart
// Phase 1 : Le nombre s'affiche avec l'animation existante (0→4280, 900ms)
// Phase 2 : RIEN. 3 secondes de silence. Pas de bouton. Pas de texte.
//           Juste le nombre, seul sur l'écran. L'utilisateur le REGARDE.
// Phase 3 : Une phrase apparaît en fade-in lent (800ms) :

AnimatedOpacity(
  opacity: _showQuestion ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 800),
  child: Column(
    children: [
      const SizedBox(height: 32),
      Text(
        S.of(context)!.chiffreChocSilenceQuestion,
        // "C'est ton chiffre. Qu'est-ce que tu en penses ?"
        style: MintTextStyles.bodyLarge().copyWith(
          color: MintColors.textMuted,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      // Phase 4 : Un champ de texte apparaît (fade-in, 500ms après la question)
      AnimatedOpacity(
        opacity: _showInput ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: TextField(
          controller: _responseController,
          decoration: InputDecoration(
            hintText: S.of(context)!.chiffreChocSilenceHint,
            // "Dis ce qui te vient..."
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.arrow_forward_rounded),
              onPressed: _responseController.text.trim().isNotEmpty
                  ? () => _navigateToCoachWithResponse()
                  : null,
            ),
          ),
          maxLines: 3,
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _navigateToCoachWithResponse(),
        ),
      ),
    ],
  ),
),
```

### Le timer du silence

```dart
@override
void initState() {
  super.initState();
  // ... existing animation init ...

  // Phase 2 : Silence de 3 secondes après l'animation du nombre
  Future.delayed(const Duration(milliseconds: 3900), () {
    // 900ms animation + 3000ms silence
    if (mounted) setState(() => _showQuestion = true);
  });

  // Phase 4 : Champ de texte 800ms après la question
  Future.delayed(const Duration(milliseconds: 4700), () {
    if (mounted) setState(() => _showInput = true);
  });
}
```

### La navigation vers le coach

```dart
void _navigateToCoachWithResponse() {
  final userFeeling = _responseController.text.trim();
  if (userFeeling.isEmpty) return;

  // Tracker le moment (analytics)
  AnalyticsService().trackEvent('chiffre_choc_feeling', {
    'length': userFeeling.length,
    'hasEmoji': userFeeling.contains(RegExp(r'[\u{1F600}-\u{1F9FF}]', unicode: true)),
  });

  // Naviguer vers le coach avec le feeling comme premier message
  context.push('/coach/chat', extra: {
    'initialPrompt': userFeeling,
    'context': 'post_chiffre_choc',
    'chiffreChocValue': _chiffreChoc?.rawValue,
  });
}
```

### Le coach reçoit le contexte émotionnel

File: apps/mobile/lib/screens/coach/coach_chat_screen.dart

Quand le chat s'ouvre avec `context: 'post_chiffre_choc'`, le system prompt
inclut une instruction spéciale :

```dart
if (widget.extra?['context'] == 'post_chiffre_choc') {
  _systemPromptAddition = '''
L'utilisateur vient de voir son chiffre de retraite pour la première fois.
Son chiffre : ${widget.extra?['chiffreChocValue']} CHF/mois.
Sa réaction spontanée : "${widget.extra?['initialPrompt']}"

C'est un moment ÉMOTIONNEL. Ne donne PAS de conseil. Ne liste PAS d'actions.
Écoute. Valide ce qu'il ressent. Pose UNE question pour approfondir.
La logique viendra après. L'empathie d'abord.

INTERDIT dans cette réponse :
- "Voici ce que tu peux faire"
- "Il existe des solutions"
- Toute liste d'actions
- Tout chiffre technique

AUTORISÉ :
- Reformuler ce qu'il a dit ("Tu trouves que c'est...")
- Poser une question ouverte ("Qu'est-ce qui t'inquiète le plus ?")
- Normaliser ("Beaucoup de gens ressentent ça")
- Être humain, pas un robot financier
''';
}
```

### Après la première réponse émotionnelle du coach

Le coach répond avec empathie. PUIS, dans le message suivant (pas le premier),
il commence à guider vers l'action :

"Maintenant qu'on a posé ça — tu veux qu'on regarde ce qu'on peut faire ?"

Et là seulement, les suggested actions apparaissent. L'émotion d'abord,
la logique ensuite. JAMAIS l'inverse.

### Bouton alternatif (pour ceux qui ne veulent pas écrire)

En dessous du champ de texte, un lien discret :

```dart
TextButton(
  onPressed: () => context.push('/home'),
  child: Text(
    S.of(context)!.chiffreChocSkipToHome,
    // "Passer au dashboard"
    style: MintTextStyles.caption().copyWith(color: MintColors.textMuted),
  ),
),
```

Petit, discret, pas le choix principal. Le choix principal c'est ÉCRIRE.

### Clés i18n (6 langues)

- chiffreChocSilenceQuestion: "C'est ton chiffre. Qu'est-ce que tu en penses ?"
  EN: "That's your number. What do you think?"
  DE: "Das ist deine Zahl. Was denkst du?"
  IT: "Questo è il tuo numero. Cosa ne pensi?"
  ES: "Este es tu número. ¿Qué piensas?"
  PT: "Este é o teu número. O que achas?"

- chiffreChocSilenceHint: "Dis ce qui te vient..."
  EN: "Say what comes to mind..."
  DE: "Sag, was dir einfällt..."
  IT: "Dì quello che ti viene in mente..."
  ES: "Di lo que se te ocurra..."
  PT: "Diz o que te vem à mente..."

- chiffreChocSkipToHome: "Passer au dashboard"

## VÉRIFICATION DE CÂBLAGE
1. Chiffre choc affiché → 3 secondes de silence → question apparaît → VÉRIFIÉ
2. Champ de texte fonctionnel → texte envoyé au coach → VÉRIFIÉ
3. Coach reçoit le contexte 'post_chiffre_choc' → VÉRIFIÉ
4. Coach répond avec empathie (pas de liste d'actions) → VÉRIFIÉ
5. Bouton "Passer au dashboard" fonctionnel → VÉRIFIÉ
6. Analytics trackEvent → VÉRIFIÉ
7. flutter analyze — 0 errors
8. flutter test — tous passent
9. git commit: "feat(soul): moment de silence — emotional chiffre choc experience"
```

---

## PROMPT 2 — Chiffre choc en 2 taps + canton (Conversion)

```
Tu es un ingénieur Flutter UX senior.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.

## RÈGLE GIT (NON-NÉGOCIABLE)
NE PAS utiliser isolation: "worktree". Travailler dans le repo principal.
git checkout -b feature/soul-2tap-chiffre-choc

## CE QU'IL FAUT CRÉER

### 3 champs inline sur le landing (pas 2 — canton est critique)

File: apps/mobile/lib/screens/landing_screen.dart

Section "Ton chiffre en 30 secondes" :

```dart
Column(
  children: [
    Text(S.of(context)!.landingQuickCalcTitle,
      style: MintTextStyles.titleMedium()),
    Text(S.of(context)!.landingQuickCalcSubtitle,
      style: MintTextStyles.bodySmall().copyWith(color: MintColors.textMuted)),
    // "Aucun compte. Rien n'est stocké. Calcul éphémère."

    const SizedBox(height: 20),

    // Champ 1 : Année de naissance
    MintPickerTile(
      label: S.of(context)!.landingBirthYear,
      value: _birthYear?.toString() ?? '',
      onTap: () => _showBirthYearPicker(),
    ),

    const SizedBox(height: 12),

    // Champ 2 : Salaire brut annuel (champ texte, pas chips)
    // Un vrai champ avec clavier numérique — pas des buckets de 50k
    // Les Suisses veulent de la PRÉCISION, pas des approximations
    TextField(
      controller: _salaryController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: S.of(context)!.landingSalary,
        // "Salaire brut annuel (CHF)"
        hintText: '85\'000',
        prefixText: 'CHF ',
        suffixIcon: _salaryController.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear),
                onPressed: () => _salaryController.clear())
            : null,
      ),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    ),

    const SizedBox(height: 12),

    // Champ 3 : Canton (CRITIQUE pour la précision)
    MintPickerTile(
      label: S.of(context)!.landingCanton,
      value: _canton ?? '',
      onTap: () => _showCantonPicker(),
    ),

    const SizedBox(height: 24),

    // Badge confiance
    Text(
      S.of(context)!.landingPrivacyBadge,
      // "Aucun compte requis. Calcul sur ton téléphone. Rien n'est stocké."
      style: MintTextStyles.caption().copyWith(
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    ),

    const SizedBox(height: 16),

    // Bouton
    FilledButton(
      onPressed: _canCalculate ? () => _showInstantChiffreChoc() : null,
      child: Text(S.of(context)!.landingCalculate),
      // "Voir mon chiffre"
    ),
  ],
)
```

### Le calcul instantané utilise le canton

```dart
bool get _canCalculate =>
    _birthYear != null && _salary != null && _salary! > 0 && _canton != null;

void _showInstantChiffreChoc() {
  final age = DateTime.now().year - _birthYear!;
  final monthlyRente = AvsCalculator.computeMonthlyRente(
    currentAge: age,
    retirementAge: 65,
    grossAnnualSalary: _salary!.toDouble(),
  );
  // LPP estimation simplifiée (sans certificat)
  final lppEstimate = LppCalculator.quickEstimate(
    currentAge: age,
    grossAnnualSalary: _salary!.toDouble(),
  );
  final totalMonthly = monthlyRente + lppEstimate;
  final netMonthly = _salary! / 12 * 0.85;
  final replacementRate = netMonthly > 0 ? totalMonthly / netMonthly : 0.0;

  // Analytics
  AnalyticsService().trackEvent('instant_chiffre_choc', {
    'age': age, 'canton': _canton, 'replacementRate': replacementRate,
  });

  // Naviguer vers le chiffre choc instantané
  // Cet écran utilise le même "moment de silence" du Prompt 1
  context.push('/chiffre-choc-instant', extra: {
    'totalMonthly': totalMonthly,
    'netMonthly': netMonthly,
    'replacementRate': replacementRate,
    'age': age,
    'salary': _salary,
    'canton': _canton,
  });
}
```

### L'écran chiffre choc instantané

File: apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart (NOUVEAU)

Écran MINIMALISTE :
- Le big number animé
- Un contexte basé sur le canton : "En {canton}, c'est {context}."
  Utiliser les thresholds du ConfidenceScorer, pas des hardcodés
- Le badge confiance : "Estimation ±15% — crée un compte pour plus de précision"
- Le MOMENT DE SILENCE (identique au Prompt 1)
- Puis : "C'est ton chiffre. Qu'est-ce que tu en penses ?"
- Si l'utilisateur écrit → naviguer vers signup PUIS coach chat
- Si l'utilisateur tape "Passer" → landing avec message "Reviens quand tu veux"

### Route publique (pas d'auth)

File: apps/mobile/lib/app.dart
Ajouter `/chiffre-choc-instant` dans les publicPrefixes.

### Comparaison VZ sur le landing

Ajouter quelque part sur le landing (au-dessus ou en dessous du calcul) :

```dart
Text(
  S.of(context)!.landingVzComparison,
  // "Ce que VZ facture 1'200 CHF, tu l'as en 30 secondes."
  style: MintTextStyles.bodySmall().copyWith(
    color: MintColors.textMuted,
  ),
),
```

## VÉRIFICATION DE CÂBLAGE
1. Landing → 3 champs visibles (birth year, salary, canton) → VÉRIFIÉ
2. Remplir + tapper → chiffre choc en <1 seconde → VÉRIFIÉ
3. Aucun compte créé, aucune donnée stockée → VÉRIFIÉ
4. Moment de silence + question + champ texte → VÉRIFIÉ
5. Analytics trackEvent → VÉRIFIÉ
6. git commit: "feat(soul): 2-tap chiffre choc on landing with canton"
```

---

## PROMPT 3 — Le coach qui attend (pas proactif, présent)

```
Tu es un ingénieur Flutter + Python senior ET un psychologue UX.

## PRÉ-VÉRIFICATION
Lis les fichiers cibles AVANT de modifier quoi que ce soit.

## RÈGLE GIT
git checkout -b feature/soul-coach-qui-attend

## CE QU'IL FAUT CRÉER

### Le coach montre UN CHIFFRE, pas un message

Quand l'utilisateur ouvre le coach (nouvelle conversation, pas reprise) :
- PAS de message proactif
- PAS de "Bonjour, comment puis-je t'aider ?"
- Un CHIFFRE. Le chiffre qui compte le plus aujourd'hui.

```dart
// Dans initState() du coach chat, si nouvelle conversation :
Widget _buildSilentOpener() {
  final cap = context.read<MintStateProvider>().state?.cap;
  if (cap == null) return const SizedBox.shrink();

  // Le chiffre clé du cap du jour
  final keyNumber = cap.estimatedImpact ?? cap.headline;

  return Container(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    child: Column(
      children: [
        // Le chiffre, gros, seul
        Text(
          keyNumber,
          style: MintTextStyles.displayLarge().copyWith(
            color: MintColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        // Une phrase courte
        Text(
          cap.headline,
          style: MintTextStyles.bodyMedium().copyWith(
            color: MintColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // "Tu veux en parler ?"
        Text(
          S.of(context)!.coachSilentOpenerQuestion,
          style: MintTextStyles.bodySmall().copyWith(
            color: MintColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    ),
  );
}
```

### Ce qui se passe quand l'utilisateur tape

Si l'utilisateur écrit quelque chose → le chiffre/opener disparaît
et la conversation commence normalement. Le coach reçoit le cap comme
contexte (via le system prompt existant) et répond en conséquence.

Si l'utilisateur ne tape rien et ferme → rien ne se passe. Pas de
notification "tu n'as pas répondu". Le coach est patient.

### Opt-in proactif APRÈS 3 sessions

Après la 3ème conversation (compteur dans SharedPreferences) :
```dart
if (_conversationCount >= 3 && !_proactiveOptInShown) {
  // À la fin de la 3ème conversation, le coach propose :
  _messages.add(ChatMessage(
    role: 'assistant',
    content: S.of(context)!.coachProactiveOptIn,
    // "Au fait — tu veux que je te signale les choses importantes
    //  quand tu ouvres l'app ? Ou tu préfères qu'on se parle
    //  seulement quand tu en as envie ?"
  ));
  _showProactiveOptInChips = true;
  // Chips : "Oui, signale-moi" / "Non, je viens quand je veux"
}
```

Si l'utilisateur accepte → les futures sessions commencent avec un
message GÉNÉRÉ par Claude basé sur le cap du jour (pré-caché en
background sur le PulseScreen, TTL 4h).

Si l'utilisateur refuse → on ne repropose JAMAIS.

### Intensité par défaut = 2 (Clair), pas 3

File: apps/mobile/lib/models/coaching_preference.dart
Changer le default :
```dart
final int cashLevel; // 1-5, default 2
// Dans le constructeur : this.cashLevel = 2
```

Le niveau 5 (Brut) n'apparaît PAS dans les chips du premier chat.
Accessible uniquement via settings ou commande vocale "mode brut".

### Analytics

```dart
AnalyticsService().trackEvent('coach_silent_opener_shown', {
  'capId': cap.id,
  'engaged': userTypedSomething, // true/false
});
AnalyticsService().trackEvent('coach_proactive_optin', {
  'accepted': userAccepted,
  'conversationCount': _conversationCount,
});
```

## VÉRIFICATION DE CÂBLAGE
1. Nouvelle conversation → chiffre affiché (pas message) → VÉRIFIÉ
2. User tape → conversation commence → VÉRIFIÉ
3. User ferme sans taper → rien ne se passe → VÉRIFIÉ
4. 3ème session → opt-in proposé → VÉRIFIÉ
5. Opt-in accepté → prochaine session a un opener Claude → VÉRIFIÉ
6. Opt-in refusé → plus jamais proposé → VÉRIFIÉ
7. cashLevel default = 2 → VÉRIFIÉ
8. git commit: "feat(soul): coach qui attend — chiffre silencieux + opt-in proactif"
```

---

## PROMPT 4 — Confidence Score + notifications séquencées (Rétention)

```
Tu es un ingénieur Flutter + notification senior.

## PRÉ-VÉRIFICATION
Lis les fichiers cibles AVANT de modifier quoi que ce soit.

## RÈGLE GIT
git checkout -b feature/soul-retention

## CE QU'IL FAUT CRÉER

### 1. Remplacer progress bar par Confidence Score sur le dashboard

File: apps/mobile/lib/screens/pulse/pulse_screen.dart

Au lieu de "Profil 45% complet" (corvée), montrer le Confidence Score
existant avec ce que l'utilisateur GAGNE en complétant :

```dart
if (confidence < 70) {
  Column(
    children: [
      // Score actuel
      Text('Fiabilité de ta projection : ${confidence.toInt()}%'),

      // Ce qui améliore le plus
      Text(
        confidence < 40
            ? S.of(context)!.confidenceLow
            // "Tes chiffres sont très approximatifs. Ajoute ton certificat LPP pour +25%."
            : S.of(context)!.confidenceMedium,
            // "Bon début. Scanne ton extrait AVS pour confirmer tes années de cotisation."
        style: MintTextStyles.bodySmall(),
      ),

      // Bouton d'action concret
      TextButton(
        onPressed: () => context.push('/scan'), // ou /profile/bilan
        child: Text(S.of(context)!.confidenceAction),
        // "Scanner mon certificat LPP (+25% de précision)"
      ),
    ],
  ),
}
```

### 2. Notifications séquencées (curiosité → loss framing)

File: apps/mobile/lib/services/notification_service.dart

**J+1 : CURIOSITÉ** (la confiance n'est pas encore établie)
```dart
static Future<void> scheduleDay1Notification({
  required String canton,
}) async {
  final tomorrow = DateTime.now().add(const Duration(hours: 24));
  await _scheduleNotification(
    id: 9001,
    title: S.current.day1NotifTitle,
    // "On a calculé quelque chose"
    body: S.current.day1NotifBody,
    // "Ouvre MINT — on a trouvé quelque chose d'intéressant sur tes impôts."
    scheduledDate: tomorrow,
    payload: '/coach/chat',
  );
}
```

**J+7 : LOSS FRAMING** (la confiance est établie)
```dart
static Future<void> scheduleDay7Notification({
  required double taxSaving3a,
}) async {
  if (taxSaving3a <= 0) return;
  final day7 = DateTime.now().add(const Duration(days: 7));
  await _scheduleNotification(
    id: 9007,
    title: S.current.day7NotifTitle,
    // "Tu laisses de l'argent au fisc"
    body: S.current.day7NotifBody(formatChf(taxSaving3a)),
    // "Chaque mois sans 3a, tu laisses CHF {amount} au fisc. On en parle ?"
    scheduledDate: day7,
    payload: '/coach/chat?prompt=parle-moi+de+mon+3a',
  );
}
```

**J+30 : SCAN NUDGE** (pousser vers le certificat LPP)
```dart
static Future<void> scheduleDay30Notification() async {
  final day30 = DateTime.now().add(const Duration(days: 30));
  await _scheduleNotification(
    id: 9030,
    title: S.current.day30NotifTitle,
    // "Ta projection peut être 25% plus précise"
    body: S.current.day30NotifBody,
    // "Scanne ton certificat LPP — ça prend 30 secondes et ça change tout."
    scheduledDate: day30,
    payload: '/scan',
  );
}
```

Appeler les 3 après l'onboarding (dans smart_onboarding_screen.dart).

### 3. Deep link sécurisé

Vérifier que le profil est chargé AVANT de naviguer via deep link.
Si le profil n'est pas prêt, afficher un splash de chargement.

## VÉRIFICATION DE CÂBLAGE
1. Dashboard → Confidence Score visible (pas progress bar) → VÉRIFIÉ
2. Confidence < 40 → message "très approximatif" + CTA scan → VÉRIFIÉ
3. J+1 notification → curiosité, pas loss framing → VÉRIFIÉ
4. J+7 notification → loss framing avec montant → VÉRIFIÉ
5. Tap notification → app ouvre au bon écran → VÉRIFIÉ
6. git commit: "feat(soul): confidence score dashboard + sequenced notifications"
```

---

## PROMPT 5 — Action engine : "fais ÇA" avec chiffre et délai

```
Tu es un ingénieur Flutter UX senior.

## PRÉ-VÉRIFICATION
Lis les fichiers cibles AVANT de modifier quoi que ce soit.

## RÈGLE GIT
git checkout -b feature/soul-action-engine

## CE QU'IL FAUT CRÉER

### ActionInsightWidget — contexte + action CONCRÈTE

File: apps/mobile/lib/widgets/action_insight_widget.dart (NOUVEAU)

Chaque nombre financier doit répondre à 3 questions :
1. C'est bien ou pas ? (contexte)
2. Qu'est-ce que je fais ? (action avec CHIFFRE et DÉLAI)
3. Combien ça rapporte ? (impact)

```dart
class ActionInsightWidget extends StatelessWidget {
  final String contextLine;
  // "62% — en dessous de la moyenne suisse (68%)"
  final String actionLine;
  // "Verse 611 CHF avant le 31 décembre"
  final String? impactLine;
  // "Économie fiscale : 1'833 CHF"
  final String? route;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.bleuAir.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.bleuAir.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contexte
          Text(contextLine, style: MintTextStyles.bodySmall()),
          const SizedBox(height: 8),
          // Action concrète
          InkWell(
            onTap: onTap ?? (route != null ? () => context.push(route!) : null),
            child: Row(
              children: [
                Expanded(
                  child: Text(actionLine,
                    style: MintTextStyles.bodySmall().copyWith(
                      color: MintColors.primary,
                      fontWeight: FontWeight.w600,
                    )),
                ),
                if (impactLine != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: MintColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(impactLine!,
                      style: MintTextStyles.caption().copyWith(
                        color: MintColors.success, fontWeight: FontWeight.w600)),
                  ),
                ],
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, size: 14, color: MintColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

### Intégrer sur les 3 écrans principaux

Le contexte vient du CapEngine (pas hardcodé). Le CapEngine sait
déjà quelle est la priorité et l'impact estimé.

**Retirement dashboard** : après le hero number
**Pulse screen** : après le dominant number
**Budget screen** : après le "reste à vivre"

Pour chaque écran, construire l'ActionInsightWidget depuis le cap :
```dart
final cap = mintState?.cap;
if (cap != null) {
  ActionInsightWidget(
    contextLine: _buildContextLine(replacementRate, l),
    actionLine: cap.ctaLabel ?? cap.headline,
    impactLine: cap.estimatedImpact,
    route: cap.route,
    onTap: () {
      AnalyticsService().trackEvent('action_cta_tapped', {
        'screen': 'retirement', 'capId': cap.id,
      });
      context.push(cap.route ?? '/coach/chat');
    },
  );
}
```

### RÈGLE : chaque action a un NOMBRE et un DÉLAI

Les CTAs génériques sont INTERDITS :
- ❌ "Simule ton 3a"
- ❌ "Explorer mes options"
- ❌ "En savoir plus"

Les CTAs MINT ont :
- ✅ "Verse 611 CHF avant le 31 décembre — économie : 1'833 CHF"
- ✅ "Rachète 20'000 CHF de LPP cette année — économie : 6'400 CHF"
- ✅ "Réduis tes charges fixes de 300 CHF/mois — 3'600 CHF/an libérés"

Le CapEngine doit fournir ces chiffres. S'il ne peut pas (données
insuffisantes), le CTA dit : "Complète ton profil pour voir l'impact exact."

## VÉRIFICATION DE CÂBLAGE
1. Retirement dashboard → ActionInsightWidget visible → VÉRIFIÉ
2. Le contexte vient du CapEngine (pas hardcodé) → VÉRIFIÉ
3. Le CTA a un chiffre et un délai → VÉRIFIÉ
4. Tap → navigation vers le bon écran → VÉRIFIÉ
5. Analytics trackEvent → VÉRIFIÉ
6. git commit: "feat(soul): action engine — concrete CTAs with numbers and deadlines"
```

---

## PROMPT 6 — Glossaire vivant + couple preview personnalisée

```
Tu es un ingénieur Flutter senior.

## PRÉ-VÉRIFICATION
Lis les fichiers cibles AVANT de modifier quoi que ce soit.

## RÈGLE GIT
git checkout -b feature/soul-glossary-couple

## PARTIE A : Glossaire vivant

### GlossaryService avec termes dans les ARB files (pas hardcodé)

File: apps/mobile/lib/services/glossary_service.dart (NOUVEAU)

```dart
class GlossaryService {
  /// Returns the localized explanation for a financial term.
  /// Terms are stored in ARB files: glossary_lpp, glossary_avs, etc.
  static String? explain(BuildContext context, String termKey) {
    final s = S.of(context)!;
    final map = {
      'LPP': s.glossaryLpp,
      'AVS': s.glossaryAvs,
      '3a': s.glossary3a,
      'RAMD': s.glossaryRamd,
      'Taux de conversion': s.glossaryTauxConversion,
      'Rachat LPP': s.glossaryRachat,
      'Lacune': s.glossaryLacune,
      'Taux de remplacement': s.glossaryTauxRemplacement,
      'Rente': s.glossaryRente,
      'Capital': s.glossaryCapital,
      'Coordination': s.glossaryCoordination,
      'Surobligatoire': s.glossarySurobligatoire,
    };
    return map[termKey];
  }

  /// Track lookup for learning curve
  static Future<void> trackLookup(String term) async {
    AnalyticsService().trackEvent('glossary_lookup', {'term': term});
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt('_glossary_${term}_count') ?? 0) + 1;
    await prefs.setInt('_glossary_${term}_count', count);
  }

  /// After 3 lookups, the user probably knows the term
  static Future<bool> userKnowsTerm(String term) async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getInt('_glossary_${term}_count') ?? 0) >= 3;
  }
}
```

### GlossaryTerm widget — tap to explain

```dart
class GlossaryTerm extends StatelessWidget {
  final String term;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: GlossaryService.userKnowsTerm(term),
      builder: (context, snapshot) {
        final known = snapshot.data ?? false;
        if (known) return Text(term, style: style); // Plus de soulignement

        return GestureDetector(
          onTap: () {
            GlossaryService.trackLookup(term);
            final explanation = GlossaryService.explain(context, term);
            if (explanation == null) return;
            showModalBottomSheet(
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
                  ],
                ),
              ),
            );
          },
          child: Text(term,
            style: (style ?? MintTextStyles.bodyMedium()).copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: MintColors.primary.withOpacity(0.5),
              color: MintColors.primary,
            )),
        );
      },
    );
  }
}
```

### Ajouter les 12 termes dans les 6 ARB files

glossaryLpp, glossaryAvs, glossary3a, glossaryRamd, glossaryTauxConversion,
glossaryRachat, glossaryLacune, glossaryTauxRemplacement, glossaryRente,
glossaryCapital, glossaryCoordination, glossarySurobligatoire

Chaque terme doit avoir une explication de 1-2 phrases en langage simple.
PAS de jargon dans l'explication du jargon.

### Placer GlossaryTerm sur les écrans clés

- Retirement dashboard : "Rente AVS + LPP" → GlossaryTerm("AVS") + GlossaryTerm("LPP")
- Chiffre choc : "Taux de remplacement" → GlossaryTerm("Taux de remplacement")
- Onboarding calibration : "avoir LPP", "taux de conversion", "3a"

## PARTIE B : Couple preview PERSONNALISÉE

File: apps/mobile/lib/screens/landing_screen.dart (ajouter section)

Si l'utilisateur a déjà entré son salaire (via le 2-tap chiffre choc),
calculer SA pénalité mariage estimée :

```dart
if (_salary != null && _canton != null) {
  final penalty = CoupleOptimizer.estimateMarriagePenalty(
    userSalary: _salary!.toDouble(),
    canton: _canton!,
  );
  if (penalty > 0) {
    // Section couple avec LEUR chiffre
    Column(
      children: [
        Text(S.of(context)!.landingCoupleTitle),
        // "En couple ? MINT optimise à deux."
        Text(
          S.of(context)!.landingCouplePersonalized(formatChf(penalty)),
          // "Avec ton revenu, la pénalité mariage estimée est de CHF {penalty}/an.
          //  3 leviers existent pour la réduire."
        ),
        OutlinedButton(
          onPressed: () => context.push('/auth/register?intent=couple'),
          child: Text(S.of(context)!.landingCoupleAction),
          // "Découvrir le mode couple"
        ),
      ],
    );
  }
} else {
  // Fallback générique (pas de salary)
  // Exemples statiques
}
```

## VÉRIFICATION DE CÂBLAGE
1. Tap "LPP" sur retirement dashboard → bottom sheet avec explication → VÉRIFIÉ
2. Après 3 taps sur "LPP" → plus de soulignement → VÉRIFIÉ
3. Analytics glossary_lookup trackés → VÉRIFIÉ
4. Couple preview avec salary personnalisé → VÉRIFIÉ
5. Couple preview sans salary → fallback générique → VÉRIFIÉ
6. flutter gen-l10n — 0 errors (12 nouvelles clés × 6 langues)
7. git commit: "feat(soul): glossary + personalized couple preview"
```

---

## PROMPT 7 — Transparence radicale (Privacy by design)

```
Tu es un expert compliance nLPD + ingénieur Flutter.

## PRÉ-VÉRIFICATION
Lis les fichiers cibles AVANT de modifier quoi que ce soit.

## RÈGLE GIT
git checkout -b feature/soul-transparency

## CE QU'IL FAUT CRÉER

### Transparence action par action

MINT doit être l'app PLUS transparente du marché suisse. Pas des
promesses vagues — une transparence RADICALE, action par action.

### 1. Sur le landing (chiffre choc instantané)

Sous les 3 champs, AVANT le bouton "Voir mon chiffre" :

```dart
Text(
  S.of(context)!.landingTransparency,
  // "Ce qui se passe quand tu tapes ton salaire : le calcul est fait
  //  sur ton téléphone. Rien n'est envoyé. Rien n'est stocké.
  //  Quand tu fermes cette page, les chiffres disparaissent."
  style: MintTextStyles.caption().copyWith(
    color: MintColors.textMuted,
    fontStyle: FontStyle.italic,
  ),
),
```

### 2. Sur l'import bancaire

Remplacer la claim mensongère par la vérité :

```dart
Text(
  S.of(context)!.bankImportTransparency,
  // "Ton relevé est envoyé à notre serveur suisse de manière chiffrée
  //  pour analyse. Les transactions sont catégorisées, puis le fichier
  //  brut est supprimé. Seuls les résumés par catégorie sont conservés
  //  dans ton profil."
),
```

### 3. Sur le coach chat

Première fois que le coach répond, ajouter un petit badge discret :

```dart
// Sous le premier message du coach
if (_isFirstMessageInSession) {
  Text(
    _usingSLM
        ? S.of(context)!.coachTransparencySLM
        // "Réponse générée sur ton téléphone (Gemma). Rien envoyé."
        : S.of(context)!.coachTransparencyBYOK,
        // "Réponse via ton API Claude. Ton salaire exact n'est PAS envoyé —
        //  seuls ton âge, canton et archétype sont partagés."
    style: MintTextStyles.caption().copyWith(
      color: MintColors.textMuted,
      fontSize: 10,
    ),
  ),
}
```

### 4. Dans les settings — page "Comment MINT utilise tes données"

Créer un écran simple accessible depuis le profil :

Route: /profile/data-transparency

Contenu structuré par action :
- "Quand tu entres ton salaire" → stocké localement en SharedPreferences chiffrées
- "Quand tu scannes un document" → envoyé au serveur, parsé, fichier supprimé
- "Quand tu parles au coach" → SLM local OU API Claude (ton choix)
- "Quand tu importes un relevé" → envoyé au serveur, catégorisé, fichier supprimé
- "Quand tu supprimes ton compte" → tout est purgé (DB + local + embeddings)

Chaque ligne a un badge : 🟢 Local | 🟡 Serveur (chiffré) | 🔴 Tiers (avec ton accord)

## VÉRIFICATION DE CÂBLAGE
1. Landing → texte de transparence visible → VÉRIFIÉ
2. Bank import → claim honnête (pas "localement") → VÉRIFIÉ
3. Coach chat → badge SLM/BYOK visible → VÉRIFIÉ
4. Settings → écran data-transparency accessible → VÉRIFIÉ
5. flutter gen-l10n — 0 errors
6. git commit: "feat(soul): radical transparency — per-action data disclosure"
```

---

## ORCHESTRATION

```
Tu es un orchestrateur de sprint. Ta mission : lancer les 7 prompts
du fichier docs/MINT_SOUL_SPRINT_PROMPTS.md.

## RÈGLE GIT CRITIQUE (NON-NÉGOCIABLE)
NE JAMAIS utiliser isolation: "worktree".
L'agent travaille DIRECTEMENT dans le repo principal.
git checkout -b feature/xxx pour chaque prompt.

## RÈGLE CÂBLAGE (NON-NÉGOCIABLE)
Après CHAQUE fix, tracer le flux end-to-end.
Si UN maillon manque → le fix n'est PAS terminé.

## PLAN D'EXÉCUTION

### VAGUE 1 — L'âme (SÉQUENTIEL — P1 est la fondation)
| Étape | Prompt | Branch |
|-------|--------|--------|
| 1a | P1 (Moment de silence) | feature/soul-moment-de-silence |
| 1b | P2 (Chiffre choc 2 taps) — APRÈS P1 | feature/soul-2tap-chiffre-choc |

P2 utilise le même moment de silence que P1.
Merger P1 → dev, puis lancer P2.

### VAGUE 2 — Le coach + rétention (2 agents EN PARALLÈLE)
| Agent | Prompt | Branch |
|-------|--------|--------|
| A | P3 (Coach qui attend) | feature/soul-coach-qui-attend |
| B | P4 (Confidence + notifications) | feature/soul-retention |

Pas de conflit. Merger : B → A

### VAGUE 3 — UX + transparence (3 agents EN PARALLÈLE)
| Agent | Prompt | Branch |
|-------|--------|--------|
| C | P5 (Action engine) | feature/soul-action-engine |
| D | P6 (Glossaire + couple) | feature/soul-glossary-couple |
| E | P7 (Transparence radicale) | feature/soul-transparency |

ATTENTION : P2 et P6 touchent tous les deux landing_screen.dart.
P2 ajoute les 3 champs + chiffre choc.
P6 ajoute la section couple preview.
Merger P2 AVANT P6. Résoudre les conflits (sections différentes).

### VÉRIFICATION FINALE — 10 TESTS DE L'ÂME

1. Chiffre choc → 3 secondes de silence → "Qu'est-ce que tu en penses ?" ✅/❌
2. L'utilisateur écrit → coach répond avec empathie (pas de liste) ✅/❌
3. Landing → 3 champs → chiffre choc SANS compte ✅/❌
4. Coach → chiffre silencieux + "Tu veux en parler ?" (pas de message proactif) ✅/❌
5. 3ème session → opt-in proactif proposé ✅/❌
6. Dashboard → Confidence Score (pas progress bar) ✅/❌
7. J+1 → notification curiosité / J+7 → loss framing ✅/❌
8. Retirement dashboard → CTA avec chiffre et délai ✅/❌
9. Tap "LPP" → explication en bottom sheet ✅/❌
10. Landing → transparence radicale visible ✅/❌

Si UN seul ❌ → l'âme n'est pas là. Sprint PAS terminé.

## CRITÈRES DE SUCCÈS
- 7/7 branches mergées
- Le moment de silence EXISTE et FONCTIONNE
- Le coach ATTEND (pas de message proactif par défaut)
- Chaque nombre dit "fais ÇA" avec un montant et un délai
- La transparence est RADICALE (pas vague)
- L'utilisateur peut ÉCRIRE ce qu'il ressent après le chiffre choc
- 0 test failures
- 0 worktree orphelines
```
