# Test Roadmap: Golden Paths & Personas

## Objectif
Valider que l'application s'adapte correctement à des profils financiers radicalement différents, en vérifiant la logique métier, la compliance (Safe Mode) et les recommandations.

## 1. Persona "Léa" (Starter / Student)
*   **Profil** : 22 ans, Étudiante/Stage, Revenu < 4k, Célibataire, Locataire.
*   **Situation** : Pas de 3a, pas de dettes, épargne faible.
*   **Flow Attendu** :
    *   Wizard : Questions simples (Skip LPP details).
    *   Rapport : Score Santé moyen (manque réserve ?).
    *   Recommandations : "Ouvrir un 3a" (Petit montant), "Réserve de sécurité".
    *   Outils : PC Module (Check -> Potentiellement éligible si revenu très bas).

## 2. Persona "Marc" (Debt Crisis / Safe Mode)
*   **Profil** : 35 ans, Employé, Revenu 6k, Célibataire.
*   **Situation** : Crédit conso en cours (10k), Leasing voiture, Retard impôts.
*   **Flow Attendu** :
    *   Wizard : Déclare dettes > 0.
    *   **Safe Mode** : ACTIVÉ.
    *   Rapport : Priorité ABSOLUE = "Rembourser dettes".
    *   Simulateurs : `RealInterest` et `Buyback` doivent être **BLOQUÉS** (Gate).
    *   Message : "Concentration prioritaire".

## 3. Persona "Sophie" (Wealth / Optimization)
*   **Profil** : 45 ans, Cadre, Revenu 12k, Mariée, 2 enfants, Propriétaire.
*   **Situation** : 3a maxé, LPP solide. Cherche optimisation fiscale.
*   **Flow Attendu** :
    *   Wizard : Déclare fortune et revenus hauts.
    *   Rapport : Score haut.
    *   Actions : "Rachat LPP" (Buyback), "Stratégie Rente/Capital".
    *   Simulateurs : Accès complet. Le comparateur "Staggered Buyback" doit montrer un gain significatif.
    *   Admin : Génération "Lettre Rachat LPP" pertinente.

## 4. Persona "Thomas" (Freelancer)
*   **Profil** : 30 ans, Indépendant, Revenu variable (8k moy).
*   **Situation** : Pas de LPP obligatoire.
*   **Flow Attendu** :
    *   Wizard : Statut "Indépendant".
    *   Logic : Vérifier que le calcul 3a utilise le plafond "20% du revenu" (max ~35k) et non le petit plafond (7k).
    *   Recommandations : "Grand 3a" comme substitut LPP.

---

## 5. Persona "Anna" (Onboarding Minimal — 3 Questions Only)
*   **Profil** : 28 ans, Salaire 75k, Canton VD. RIEN D'AUTRE.
*   **Flow Attendu** :
    *   Onboarding minimal : 3 questions seulement.
    *   Chiffre choc : "À la retraite, ton revenu estimé : CHF X/mois."
    *   Confiance : ~25% (afficher "Estimation basée sur 3 informations").
    *   Action : "Ouvrir un 3a" (car non déclaré).
    *   Arbitrage : NON accessible (confiance trop basse).

## 6. Persona "Pierre" (Arbitrage Rente vs Capital)
*   **Profil** : 58 ans, Cadre 130k, Marié, LPP 450k (300k oblig + 150k suroblig).
*   **Certificat LPP scanné** : confiance 85%.
*   **Flow Attendu** :
    *   Arbitrage rente vs capital : 3 options (full rente, full capital, mixte).
    *   Mixte doit montrer : oblig en rente (6.8%), suroblig en capital.
    *   Breakeven age calculé et affiché.
    *   Calendrier retraits : stagger 3a/LPP/conjoint.
    *   Chiffre choc : "En étalant tes retraits, tu économises ~CHF X d'impôt."

## 7. Persona "Julia" (Expat EU — Gaps)
*   **Profil** : 35 ans, Expat EU arrivée à 28, 90k, VD.
*   **Flow Attendu** :
    *   Archetype détecté : `expat_eu`.
    *   Chiffre choc prioritaire : "Tu as X années de cotisation AVS manquantes."
    *   AVS projetée inférieure à swiss_native équivalent.
    *   Convention bilatérale mentionnée.
    *   Arbitrage allocation annuelle : 3a prioritaire.

## 8. Persona "Laurent" (Coach Vivant — BYOK Active)
*   **Profil** : 40 ans, 100k, ZH, marié, 2 enfants, propriétaire. BYOK configuré.
*   **Flow Attendu** :
    *   Dashboard : greeting personnalisé (LLM via ComplianceGuard).
    *   Score summary : FRI affiché avec breakdown.
    *   Tip narratif : croisement archetype + calendar (si oct-dec → 3a).
    *   Milestone : si 3a maxé → celebration sans social comparison.
    *   Fallback test : désactiver BYOK → templates enrichis, app identique fonctionnellement.

## 9. Persona "Nadia" (Document Scan — LPP Certificate)
*   **Profil** : 42 ans, 85k, GE. Scanne son certificat LPP.
*   **Flow Attendu** :
    *   OCR extrait : avoir total, oblig/suroblig split, taux conversion, lacune rachat.
    *   Review screen : user confirme les valeurs.
    *   Confiance bondit de ~40% à ~70%.
    *   Rente vs capital maintenant accessible et précis.
    *   Chiffre choc recalculé avec vrais chiffres.

---

## Stratégie d'Exécution
Pour chaque persona, nous allons créer un **Test d'Intégration Flutter** (`integration_test/`) qui :
1.  Lance l'app.
2.  Remplit le Wizard avec les réponses spécifiques.
3.  Vérifie l'écran de Rapport généré (Textes, Scores).
4.  Navigue vers `/tools` et vérifie l'état des verrous (Safe Mode).
