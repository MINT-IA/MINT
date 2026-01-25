# BUSINESS MODEL - COMMISSIONS D'AFFILIATION

**Date** : 18 janvier 2026  
**Objectif** : Monétisation via recommandations financières qualifiées

---

## 💰 SOURCES DE REVENUS PRINCIPALES

### 1. Programmes d'Affiliation 3a (Pilier le plus rentable)

#### VIAC
- **Commission** : ~120-150 CHF par ouverture de compte
- **Bonus récurrent** : Possible selon volume (à négocier)
- **Comment** : Lien tracké via code partenaire
- **Conversion estimée** : 15-25% des utilisateurs avec 3a bancaire
- **Potentiel** : 1000 users → 200 conversions → 24'000 CHF

#### Finpension
- **Commission** : ~100-130 CHF par compte
- **Avantages** : Frais les plus bas (0.39%), arguments forts
- **Conversion estimée** : 10-20%
- **Potentiel** : 1000 users → 150 conversions → 15'000 CHF

#### frankly (ZKB)
- **Commission** : ~80-100 CHF
- **Avantages** : Marque établie (ZKB), rassurant
- **Conversion estimée** : 5-10%

---

### 2. Programmes d'Affiliation Assurances (Revenus récurrents)

#### Assurances complémentaires (LAMal compléments)
- **Commission** : 50-200 CHF selon couverture
- **Partenaires potentiels** : Assura, CSS, Helsana
- **Récurrence** : Possibilité de trailing commission (~5-10% primes annuelles)

#### Assurance risque pur (3e pilier assurance)
- **Commission** : 100-500 CHF selon prime
- **Trailing** : Possible sur durée contrat

---

### 3. Programmes d'Affiliation Hypothèques

#### Hypothèque.ch, MoneyPark, Comparis
- **Commission** : 200-1000 CHF par hypothèque signée
- **Volume** : Élevé (achat immobilier = décision majeure)
- **Conversion** : Faible (2-5%) mais montant élevé

---

### 4. Services Premium (Abonnement)

#### MINT Pro (à développer)
- **Prix** : 9.90 CHF/mois ou 99 CHF/an
- **Inclus** :
  - Suivi continu (notifications événements vie)
  - Export PDF illimité
  - Simulations avancées
  - Accès prioritaire nouveautés
  - Conseiller humain 1x/an (vidéo 30 min)

**Potentiel** : 1000 users → 10% conversion → 100 * 99 CHF = 9'900 CHF/an

---

## 🎯 STRATÉGIE DE MONÉTISATION ÉTHIQUE

### Principes Fondamentaux

1. **Transparence Totale**
   ```
   💡 Recommandation : VIAC
   ⚠️ Transparence : MINT touche une commission si tu ouvres via notre lien.
                      Cela ne change rien pour toi (pas de frais supplémentaires).
   ```

2. **Neutralité des Calculs**
   - Les calculs et scores sont **100% indépendants** des commissions
   - VIAC est recommandé CAR il est objectivement meilleur (frais 0.52% vs 1.5%)
   - Pas de fausse recommandation pour gagner plus

3. **Toujours Proposer Alternatives**
   ```
   Recommandation MINT : VIAC (0.52% frais)
   
   Alternatives :
   - Finpension (0.39% - encore moins cher)
   - frankly (0.49% - ZKB, marque établie)
   - Banque classique (1.5% - facilité si déjà client)
   ```

4. **Opt-out Possible**
   - User peut choisir "Je vais le faire moi-même ailleurs"
   - On affiche quand même les infos (nom provider, démarches)

---

## 📊 PROJECTIONS FINANCIÈRES (12 mois)

### Scénario Conservateur

**Base** : 1'000 utilisateurs actifs sur 12 mois

| Source | Conv. | Prix/User | Total |
|--------|-------|-----------|-------|
| VIAC 3a | 15% | 120 CHF | 18'000 CHF |
| Finpension | 10% | 100 CHF | 10'000 CHF |
| Assurances | 5% | 150 CHF | 7'500 CHF |
| MINT Pro | 10% | 99 CHF | 9'900 CHF |
| **TOTAL** | | | **45'400 CHF** |

### Scénario Optimiste

**Base** : 5'000 utilisateurs actifs

| Source | Conv. | Prix/User | Total |
|--------|-------|-----------|-------|
| VIAC 3a | 20% | 120 CHF | 120'000 CHF |
| Finpension | 15% | 100 CHF | 75'000 CHF |
| Assurances | 8% | 150 CHF | 60'000 CHF |
| Hypothèques | 3% | 500 CHF | 75'000 CHF |
| MINT Pro | 15% | 99 CHF | 74'250 CHF |
| **TOTAL** | | | **404'250 CHF** |

---

## 🛠️ IMPLÉMENTATION TECHNIQUE

### Tracking des Conversions

```dart
class AffiliateTracker {
  // Génère lien tracké unique par utilisateur
  String generateTrackedLink(String provider, String userId) {
    final trackingCode = generateUniqueCode(userId);
    
    switch (provider) {
      case 'viac':
        return 'https://viac.ch/?ref=mint_$trackingCode';
      case 'finpension':
        return 'https://finpension.ch/?partner=mint&code=$trackingCode';
      default:
        return '';
    }
  }
  
  // Log événement conversion (pour analytics)
  void logConversion(String userId, String provider, double commission) {
    // Track dans DB + Analytics
  }
}
```

### Widget Recommandation

```dart
class RecommendationCard extends StatelessWidget {
  final String provider;
  final double commission;
  final bool showTransparency;
  
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          Text('💡 Notre recommandation : $provider'),
          // Affichage des avantages objectifs
          Text('✓ Frais : 0.52%/an'),
          Text('✓ Rendement moyen : 4.5%'),
          
          if (showTransparency)
            TransparencyBadge(
              text: 'MINT touche une commission sans frais pour toi',
            ),
          
          FilledButton(
            onPressed: () => openTrackedLink(),
            child: Text('Ouvrir mon compte $provider'),
          ),
          
          TextButton(
            onPressed: () => showAlternatives(),
            child: Text('Voir d\'autres options'),
          ),
        ],
      ),
    );
  }
}
```

---

## 📝 ASPECTS LÉGAUX

### Conformité FINMA (Suisse)

- **Pas de conseil financier** : MINT est un outil d'information, pas un conseiller
- **Disclaimer obligatoire** :
  ```
  MINT est une plateforme d'éducation financière. 
  Nous ne sommes pas conseillers financiers au sens légal.
  Les calculs sont à titre indicatif. Consultez un professionnel pour décisions importantes.
  ```
- **Transparence commissions** : Obligatoire selon loi consommateurs

### Protection Données (LPD / RGPD)

- **Consentement explicite** pour tracking affiliation
- **Opt-out** possible à tout moment
- **Anonymisation** des données après conversion

---

## 🚀 ROADMAP MONÉTISATION

### Phase 1 : MVP (Mois 1-3)
- [x] Recommandations VIAC/Finpension
- [ ] Liens trackés
- [ ] Dashboard tracking conversions
- [ ] Négociation contrats affiliation

### Phase 2 : Croissance (Mois 4-6)
- [ ] Ajout assurances complémentaires
- [ ] MINT Pro (abonnement)
- [ ] Programme parrainage (viral)

### Phase 3 : Scalabilité (Mois 7-12)
- [ ] Hypothèques
- [ ] LPP rachats (partenaires caisses)
- [ ] API partenaires (intégration directe)

---

## 💡 IDÉES BONUS

### Programme Parrainage

```
Parraine un ami :
- Lui : Diagnostic gratuit
- Toi : 20 CHF crédit MINT Pro OU don à organisation de ton choix
```

### Gamification

```
Achievements :
🏆 "3a Optimisé" → Ouvert compte VIAC → Badge + 1 mois MINT Pro gratuit
🏆 "Budget Zen" → Fonds urgence 6 mois → Badge
```

---

**Bottom Line** : Monétisation éthique basée sur la **vraie valeur ajoutée** (meilleurs produits) + **transparence totale** = Win-win-win (User, MINT, Partenaires)
