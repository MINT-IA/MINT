
# 🧪 Testing Guide: MINT "Swiss Expert" Update (v1.1.0)

> "La confiance n'exclut pas le contrôle." - Proverbe (Léniniste, mais utile en QA)

Ce guide décrit les scénarios de test pour valider la transformation de MINT en Mentor Financier Suisse Situationnel.

---

## 1. Test de la Navigation "Situationnelle"
**Objectif** : Vérifier que l'utilisateur n'est plus bloqué dans un wizard linéaire.

1.  **Lancer l'App**.
2.  Vérifier que la barre de navigation contient : `Home | Budget | Parcours | Profil`.
3.  **Tap sur "Budget"** :
    *   *Attendu* : Doit ouvrir l'écran Budget (ou Empty State). Ne doit PAS lancer le Wizard.
4.  **Tap sur "Parcours"** (icône Timeline) :
    *   *Attendu* : Doit afficher la Timeline "Mon Parcours" avec les sections "Immédiat", "Court Terme", "Vie".
5.  **Tap sur "Maîtrise du Cashflow"** (dans la Timeline) :
    *   *Attendu* : Redirige vers l'écran Budget.

## 2. Test du "Cerveau Fiscal" (Scenario: Vaud Single)
**Objectif** : Vérifier que MINT estime les impôts sans qu'on lui dise.

1.  Allez sur l'onglet **Parcours** -> Touchez "Protection de Base" (Lancer Check-up).
2.  **Répondez aux questions** :
    *   Prénom : "Jean"
    *   Année : "1990"
    *   **Canton : "Vaud (VD)"** (Crucial)
    *   **Statut : "Célibataire"**
    *   Enfants : "Non"
    *   Revenu Net : "8'000" (Mensuel) -> ~96k/an
    *   LPP : "Oui"
    *   3a : "Non"
3.  **Avancez jusqu'au rapport**.
4.  **Vérifiez le Scoreboard** :
    *   *Attendu* : Une case "Impôts Estimés" affiche **~1'100 - 1'400 CHF/m** (Prov. Vaud).
    *   *Note* : Si vous aviez mis "Zoug", ce montant devrait être ~600-800 CHF.

## 3. Test du "Risque Juridique" (Scenario: Concubins)
**Objectif** : Vérifier l'alerte intelligente.

1.  Relancez le Wizard (ou faites "Précédent").
2.  Changez **Statut Familial** pour : **"Concubinage (Vie commune)"**.
3.  Générez le rapport.
4.  **Vérifiez les "Top 3 Actions"** :
    *   *Attendu* : L'Action #1 (Rouge/Critique) doit être **"Protéger votre conjoint(e)"**.
    *   *Message* : "En concubinage, 0% protection décès..."

## 4. Test du Budget Autonome
**Objectif** : Vérifier l'intégration.

1.  Allez sur l'onglet **Budget**.
2.  Si "Empty State" -> Cliquez "Configurer".
3.  Une fois le budget affiché :
    *   Vérifiez que vous pouvez modifier les enveloppes.
    *   Vérifiez que le montant "Revenus" correspond à ce que vous avez mis (si connecté).

---

## Sign-off Checklist
- [ ] Navigation fluide sans crash.
- [ ] Calcul fiscal cohérent (Vaud > Zoug).
- [ ] Alerte Concubinage présente si nécessaire.
- [ ] Rapport PDF générable (Feature à venir, check UI pour l'instant).

*Fin du protocole.*
