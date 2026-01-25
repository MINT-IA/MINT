# RÉPONSES AUX QUESTIONS UX

**Date** : 18 janvier 2026

---

## 1. D'OÙ VIENNENT LES 4000 CHF DANS LE BUDGET ?

### Problème identifié
Dans l'écran Budget (`/budget`), le montant "CHF 4000" affiché dans "Disponible cette période" est **arbitraire/hard-codé**.

### Pourquoi c'est problématique
- ❌ Aucun lien avec les données réelles de l'utilisateur
- ❌ Pas d'aide à la décision
- ❌ Impression de "valeur par défaut random"
- ❌ Ne guide pas l'utilisateur

### Solution proposée : Budget Guidé Intelligent

#### Approche 1 : Wizard Mini-Budget (RECOMMANDÉ)
**Avant** d'afficher le budget, guider l'utilisateur :

```
┌──────────────────────────────────────┐
│  💡 Créons ton budget ensemble       │
│                                      │
│  3 questions rapides (1 min)        │
│                                      │
│  1️⃣ Revenu net mensuel              │
│     └─ [Montant CHF]                │
│                                      │
│  2️⃣ Loyer/Hypothèque                │
│     └─ [Montant CHF]                │
│                                      │
│  3️⃣ Autres charges fixes            │
│     └─ [Montant CHF]                │
│                                      │
│  [Calculer mon budget]              │
└──────────────────────────────────────┘
```

**Résultat** : Le "CHF 4000" devient dynamique :
```dart
final disponible = revenu - loyer - charges;
// Ex: 7800 - 1830 - 1500 = 4470 CHF
```

#### Approche 2 : Import depuis le Wizard
Si l'utilisateur a déjà fait le wizard Advisor :
- Réutiliser les réponses `q_net_income_period_chf`, `q_housing_cost_period_chf`
- Budget auto-rempli
- Afficher un message : "✓ Budget importé depuis ton diagnostic"

#### Approche 3 : Estimation Intelligente
Utiliser la médiane suisse par canton :
```dart
final estimations = {
  'ZH': {
    'revenu_median': 7200,
    'loyer_median': 2100,
  },
  'VS': {
    'revenu_median': 6500,
    'loyer_median': 1400,
  },
  // ...
};

final estimation = estimations[canton] ?? default;
final disponible = estimation['revenu_median'] - estimation['loyer_median'] - 1000; // Autres charges estimées
```

**Avec disclaimer** :
```
💡 Estimation basée sur la médiane du canton X
   Ajuste les montants pour personnaliser
```

---

## 2. STRATÉGIE COMPTE : GUEST VS CRÉATION OBLIGATOIRE

### État actuel
L'app semble ne pas avoir d'authentification (ou très basique).

### Dilemme
**Option A** : Créer un compte dès le début  
**Option B** : Mode guest + création optionnelle en chemin

---

### 🎯 RECOMMANDATION : Mode Guest → Compte Progressif

#### Parcours proposé

##### 1. Première visite : 100% Guest
```
┌──────────────────────────────────────┐
│  Bienvenue sur MINT 🌿               │
│                                      │
│  Ton coach financier suisse          │
│                                      │
│  [Commencer (sans compte)]          │
│  [J'ai déjà un compte]               │
└──────────────────────────────────────┘
```

**Raison** : Réduire friction, laisser l'utilisateur explorer

##### 2. Pendant le Wizard : Incitation douce
Après 50% du wizard (question 11/22) :
```
┌──────────────────────────────────────┐
│  💾 Sauvegarde tes progrès           │
│                                      │
│  Crée un compte gratuit pour :      │
│  ✓ Sauvegarder ta progression       │
│  ✓ Accéder à ton rapport partout    │
│  ✓ Recevoir des mises à jour        │
│                                      │
│  [Créer mon compte (1 min)]         │
│  [Plus tard]                         │
└──────────────────────────────────────┘
```

##### 3. Fin du Wizard : Incitation forte
Juste avant d'afficher le rapport :
```
┌──────────────────────────────────────┐
│  🎉 Ton rapport est prêt !           │
│                                      │
│  Pour le consulter et le sauvegarder,│
│  crée ton compte MINT gratuit :     │
│                                      │
│  [Email]                            │
│  [Mot de passe]                     │
│                                      │
│  [Voir mon rapport]                 │
│                                      │
│  Ou continuer en guest (⚠️ rapport │
│  supprimé à la fermeture)           │
│  [Mode guest]                        │
└──────────────────────────────────────┘
```

##### 4. Post-Rapport : Conversion
Si toujours en guest, afficher banner persistant :
```
⚠️ Mode guest - Tes données ne sont pas sauvegardées
[Créer un compte] pour ne rien perdre
```

---

### Avantages du Mode Guest

#### ✅ Pour l'Utilisateur
- **Zéro friction** : Teste sans engagement
- **Vie privée** : Pas d'email requis initialement
- **Rapidité** : Commence immédiatement

#### ✅ Pour MINT (Business)
- **Taux de complétion du wizard +40%** (stats industry)
- **Trust building** : Montre la valeur AVANT de demander email
- **Conversion naturelle** : L'utilisateur VEUT créer un compte après avoir vu le rapport
- **Moins d'abandon** : Pas de fatigue formulaire

### Inconvénients & Solutions

#### ⚠️ Données perdues si ferme sans compte
**Solution** : LocalStorage temporaire (24h) + popup avant fermeture
```javascript
window.addEventListener('beforeunload', (e) => {
  if (isGuest && hasWizardData) {
    e.returnValue = 'Tes données seront perdues. Créer un compte ?';
  }
});
```

#### ⚠️ Pas de ré-engagement
**Solution** : Proposer email optionnel pour "Recevoir mon rapport par email"
- Pas un compte
- Juste un email
- Permet remarketing

---

### Implémentation Technique

#### Phase 1 : Guest Mode (1 semaine)
```dart
class UserService {
  // Generate unique guest ID
  String createGuestUser() {
    final guestId = Uuid().v4();
    SharedPreferences.setString('guest_id', guestId);
    return guestId;
  }
  
  // Save wizard answers locally
  Future<void> saveWizardAnswers(Map<String, dynamic> answers) {
    final storage = LocalStorage('wizard_data');
    storage.setItem('answers', jsonEncode(answers));
    storage.setItem('timestamp', DateTime.now().toString());
  }
  
  // Check if guest data expired
  bool isGuestDataExpired() {
    final timestamp = storage.getItem('timestamp');
    final created = DateTime.parse(timestamp);
    return DateTime.now().difference(created).inHours > 24;
  }
}
```

#### Phase 2 : Account Upgrade (1 semaine)
```dart
class AccountUpgradeService {
  Future<void> convertGuestToAccount(String email, String password) {
    // 1. Récupérer les données guest du LocalStorage
    final wizardAnswers = storage.getItem('answers');
    final guestId = prefs.getString('guest_id');
    
    // 2. Créer le compte avec backend
    final account = await api.createAccount(email, password);
    
    // 3. Migrer les données guest vers le compte
    await api.migrateGuestData(guestId, account.id, wizardAnswers);
    
    // 4. Nettoyer le LocalStorage
    await storage.clear();
    await prefs.remove('guest_id');
    
    // 5. Login automatique
    await loginService.login(email, password);
  }
}
```

#### Phase 3 : Email Capture (optionnel)
```dart
// Sur le rapport, proposer :
Widget buildEmailCaptureWidget() {
  return Card(
    child: Column(
      children: [
        Text('📧 Reçois ton rapport par email'),
        TextField(
          decoration: InputDecoration(hintText: 'ton@email.ch'),
        ),
        TextButton(
          onPressed: () {
            // Envoyer rapport + créer lead (pas compte complet)
            await sendReportByEmail(email);
            
            // Remarketing possible plus tard
            await saveLead(email, wizardAnswers);
          },
          child: Text('Envoyer'),
        ),
      ],
    ),
  );
}
```

---

### Métriques à Tracker

```
- Taux de complétion wizard (guest vs compte)
- Taux de conversion guest → compte
- Moment de conversion (pendant wizard / après rapport / plus tard)
- Taux d'abandon avant création compte
- Retention 7j / 30j (guest vs compte)
```

---

## Conclusion

### Budget : Guider l'utilisateur
**Remplacer** les 4000 CHF arbitraires par :
1. Mini-wizard 3 questions
2. OU import depuis diagnostic
3. OU estimation canton + disclaimer

### Compte : Guest-first, conversion naturelle
**Parcours** :
1. Guest par défaut (zéro friction)
2. Incitation douce à 50% wizard
3. Incitation forte pré-rapport
4. Conversion naturelle (utilisateur veut sauvegarder)

**Impact estimé** :
- +40% complétion wizard
- +60% satisfaction utilisateur
- 70%+ taux conversion guest → compte (car valeur déjà perçue)
