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

## Stratégie d'Exécution
Pour chaque persona, nous allons créer un **Test d'Intégration Flutter** (`integration_test/`) qui :
1.  Lance l'app.
2.  Remplit le Wizard avec les réponses spécifiques.
3.  Vérifie l'écran de Rapport généré (Textes, Scores).
4.  Navigue vers `/tools` et vérifie l'état des verrous (Safe Mode).
