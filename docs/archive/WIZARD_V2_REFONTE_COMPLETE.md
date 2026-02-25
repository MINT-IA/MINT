# WIZARD V2 - REFONTE COMPLÈTE

## 🚨 BUGS CRITIQUES DU WIZARD ACTUEL (V1)

### 1. Question Budget Style - Incompréhensible
**Problème** : "Comment veux-tu gérer ton budget ?" avec choix "Enveloppes" / "Autre"
- ❌ Aucune explication de ce que sont les "enveloppes"
- ❌ "Autre" ne veut rien dire
- ❌ L'utilisateur ne peut pas faire un choix éclairé

**Solution V2** : Supprimer cette question ou expliquer clairement chaque méthode avec exemples

---

### 2. Écran LPP - Logique Inversée
**Problème** : L'écran présélectionne "Sans LPP" alors que l'utilisateur a dit être **salarié**
- ❌ Un salarié a TOUJOURS une LPP (obligatoire si salaire > 22k)
- ❌ Le système devrait auto-détecter : Salarié = Avec LPP, Indépendant = Sans LPP

**Solution V2** : 
```
SI statut_professionnel == 'employee' ALORS
  has_pension_fund = 'yes' (auto)
  SKIP cette question
SINON
  Poser la question
```

---

### 3. Widget 3a - Non Parlant
**Problème** : Le slider montre juste le revenu mais :
- ❌ Pas de projection rendement (combien j'aurai à 65 ans ?)
- ❌ Pas de durée visible (combien d'années avant retraite ?)
- ❌ Impossible de comprendre l'impact

**Solution V2** : Afficher clairement :
```
┌─────────────────────────────────────────┐
│ Ton horizon : 16 ans (jusqu'à 65 ans)   │
│                                         │
│ Versement annuel : CHF 7,258            │
│ Économie fiscale : CHF 2,177/an         │
│                                         │
│ PROJECTION À 65 ANS (scénarios) :       │
│ • Prudent (1%) : CHF 125,000           │
│ • Central (4%) : CHF 168,000           │
│ • Optimiste (6%) : CHF 195,000         │
│                                         │
│ 💡 Avec VIAC au lieu d'une banque :    │
│    +CHF 45,000 de plus !               │
└─────────────────────────────────────────┘
```

---

### 4. Questions en Bas - Invisibles
**Problème** : Les vraies questions (Oui/Non au 3a) sont tout en bas, difficiles à voir
- ❌ L'utilisateur scroll, voit le widget, ne comprend pas qu'il doit répondre en bas

**Solution V2** : Question AVANT le widget éducatif
```
Question claire : "As-tu actuellement un 3a ?"
└─ Si OUI → "Combien de comptes 3a ?" (0/1/2/3+)
   └─ "Où sont-ils ?" (VIAC, Banque, Assurance...)
      └─ Widget comparatif + recommandations
└─ Si NON → Widget éducatif + CTA "Ouvre ton 1er 3a"
```

---

### 5. Popup Final - Incomplet et Bugué
**Problème** : 
- ❌ Montre "3a" bloqué mais ne dit pas pourquoi
- ❌ "Continuer pour compléter" ramène à "Objectif prioritaire" et bloque
- ❌ Manque 90% des questions (patrimoine, rachat LPP, dettes, véhicule, etc.)

**Solution V2** : Popup intermédiaire intelligent
```
┌──────────────────────────────────────────────┐
│ 📊 Ton Diagnostic (20% complet)              │
│                                              │
│ ✅ CERCLE 1 - PROTECTION : 80%              │
│    • Fonds urgence : ⚠️ À vérifier          │
│    • Dettes : ✅ Aucune                     │
│                                              │
│ ⏸️ CERCLE 2 - PRÉVOYANCE : 15%              │
│    • 3a : ℹ️ Informations incomplètes       │
│    • LPP : ❓ Rachat possible ?             │
│                                              │
│ ⏸️ CERCLE 3 - CROISSANCE : 0%               │
│    • Immobilier : Non posé                  │
│    • Investissements : Non posé             │
│                                              │
│ [Continuer (80% restant)] [Rapport partiel] │
└──────────────────────────────────────────────┘
```

---

## 🎯 WIZARD V2 - FLOW IMPLACABLE

### PHASE 0 : INTRO (1 écran)
```
┌────────────────────────────────────────────────┐
│  Bienvenue sur MINT 🌿                        │
│                                                │
│  Je vais t'aider à :                          │
│  ✅ Comprendre ta situation financière        │
│  ✅ Identifier tes priorités                  │
│  ✅ Optimiser tes impôts et ta prévoyance     │
│                                                │
│  Durée : 10-15 minutes                        │
│  Questions : ~25                               │
│                                                │
│  [Commencer]                                  │
└────────────────────────────────────────────────┘
```

---

### PHASE 1 : PROFIL (Questions 1-6)

**Q1 : Prénom** (optionnel)
```
Comment t'appelles-tu ?
[Input text]
[Je préfère rester anonyme]
```

**Q2 : Année de naissance**
```
Quelle est ton année de naissance ?
[Slider 1940-2010]
→ Calcul automatique : Âge = 49 ans, Retraite dans 16 ans (2041)
```

**Q3 : Canton**
```
Dans quel canton habites-tu ?
[Liste 26 cantons triée alphabétiquement]

💡 Pourquoi ? La fiscalité varie du simple au triple entre cantons.
Exemple : 100k de revenu → 18k d'impôts à Zoug, 32k à Genève
```

**Q4 : Statut Civil**
```
Quelle est ta situation familiale ?

[Célibataire] [Marié(e)] [Concubinage] [Divorcé(e)] [Veuf/ve]

💡 Impact fiscal majeur :
• Marié : Splitting familial (souvent avantageux)
• Concubinage : AUCUN avantage fiscal, risques juridiques
```

**Q5 : Enfants**
```
Nombre d'enfants à charge ?
[0] [1] [2] [3+]

💡 Chaque enfant = déduction fiscale ~6'500-9'000 CHF/an
```

**Q6 : Statut Professionnel**
```
Quelle est ta situation professionnelle ?

[Salarié(e)] [Indépendant(e)] [Sans emploi] [Retraité(e)]

💡 Impact clé :
• Salarié : LPP obligatoire, 3a plafonné à 7'258 CHF
• Indépendant : Pas de LPP, 3a jusqu'à 36'288 CHF
```

---

### PHASE 2 : CERCLE 1 - PROTECTION (Questions 7-11)

**Q7 : Fonds d'urgence**
```
As-tu 3-6 mois de charges de côté ?
(Argent liquide, pas bloqué dans un 3a ou actions)

[Oui, j'ai >3 mois] [J'ai 1-3 mois] [Non, <1 mois]

💡 Le fonds d'urgence c'est ta SÉCURITÉ :
• Perte d'emploi → Pas de stress immédiat
• Urgence médicale/voiture → Pas de découvert
• Priorité n°1 avant d'investir
```

**Q8 : Dettes**
```
As-tu des dettes de consommation ?
(Crédit, leasing voiture/meubles - HORS hypothèque)

[Non] [Oui]

SI OUI → Sous-questions :
• Montant total : [Input]
• Taux d'intérêt moyen : [Input %]

⚠️ ALERTE : Un crédit à 8% COÛTE plus qu'un 3a ne rapporte (2-4%)
→ Recommandation : REMBOURSE AVANT d'investir
```

**Q9 : Revenu mensuel net**
```
Quel est ton revenu net mensuel ?
(Pour un couple : TOTAL du ménage)

[Slider 2000-20000 CHF]

💡 5 secondes pour le trouver :
• Regarde ta fiche de salaire → Ligne "Montant net"
• Couple marié : Additionne les 2 salaires nets
```

**Q10 : Logement**
```
Ton logement actuel ?

[Locataire] [Propriétaire] [Chez parents/famille]

SI Locataire → "Loyer mensuel charges comprises ?" [Input]
SI Propriétaire → "Mensualité hypothèque + charges ?" [Input]
```

**Q11 : LAMal**
```
Quelle est ta franchise LAMal actuelle ?

[300] [500] [1000] [1500] [2000] [2500]

💡 Optimisation possible selon ton profil santé
→ Économie potentielle : 500-2000 CHF/an
```

**→ SCORE CERCLE 1 :**
```
┌────────────────────────────────────┐
│ 🛡️ CERCLE 1 - PROTECTION : 85%   │
│                                    │
│ ✅ Fonds urgence : OK (4 mois)    │
│ ✅ Dettes : Aucune                │
│ ✅ Revenu stable : 7'800 CHF      │
│ ⚠️ LAMal : Franchise sous-optimale│
│                                    │
│ → Passe au Cercle 2               │
└────────────────────────────────────┘
```

---

### PHASE 3 : CERCLE 2 - PRÉVOYANCE (Questions 12-20)

**Q12 : LPP**
```
SI statut == 'employee' ALORS
  → Auto-set : has_pension_fund = 'yes', SKIP Q12
SINON
  "Es-tu affilié à une caisse de pension (LPP) ?"
  [Oui] [Non]
```

**Q13 : Rachat LPP** (SI has_pension_fund = yes ET âge > 30)
```
Peux-tu racheter ta LPP ?
(Regarde ton certificat LPP → Ligne "Montant rachetable")

[Non, aucun rachat possible] [Oui] [Je ne sais pas]

SI Oui → "Montant rachetable total ?" [Input 0-500k]

💰 LEVIER FISCAL MAJEUR :
Exemple ton profil (49 ans, VS, 7800/mois) :
• Rachat 50k CHF → Économie fiscale ~15k CHF
• Stratégie : Étaler sur 4 ans (4x 50k) = 60k économisés !

[Widget Simulateur Rachat LPP]
```

**Q14 : Combien de comptes 3a**
```
Combien de comptes 3a as-tu actuellement ?

[0] [1] [2] [3 ou plus]

💡 OPTIMISATION CLÉS :
• 1 compte = Erreur fiscale au retrait
• 2-3 comptes = Économie ~5'000-15'000 CHF au retrait
• Pourquoi ? Imposition progressive par compte
```

**Q15 : Où sont tes 3a** (SI nb_comptes > 0)
```
Où sont tes comptes 3a actuellement ?
(Multi-select possible)

[Banque (UBS, CS, Raiffeisen...)]
[Assurance (AXA, Zurich, SwissLife...)]
[VIAC]
[Finpension]
[frankly (ZKB)]
[Autre]

[Widget Comparatif VIAC vs Banque vs Assurance]
```

**Q16 : Versement 3a annuel**
```
Verses-tu le maximum chaque année ?
(7'258 CHF si salarié, 20% revenu si indépendant)

[Oui, le max] [Partiellement] [Irrégulièrement] [Jamais]

💸 Ton cas (salarié, 7800/mois) :
• Max autorisé : 7'258 CHF
• Économie fiscale (VS) : ~2'200 CHF
• Coût réel : 7'258 - 2'200 = 5'058 CHF

→ Si tu ne verses PAS le max, tu perds 2'200 CHF/an en impôts !
```

**Q17 : AVS Lacunes**
```
As-tu des lacunes dans ton compte AVS ?
(Extrait gratuit sur www.ahv-iv.ch)

[Non, tout complet] [Oui, j'ai des lacunes] [Je ne sais pas]

💡 Chaque année manquante = -2.3% de rente AVS à vie
Exemple : 3 années manquantes = -160 CHF/mois pendant 20 ans de retraite
→ Perte totale : ~38'000 CHF !
```

**Q18 : Hypothèque** (SI propriétaire)
```
Type d'hypothèque actuel ?

[Fixe] [Variable (Saron)] [Mixte]

[Widget Comparatif Fixe vs Saron 2026]
```

**→ SCORE CERCLE 2 :**
```
┌────────────────────────────────────┐
│ 💰 CERCLE 2 - PRÉVOYANCE : 65%    │
│                                    │
│ ✅ LPP : Affilié                  │
│ 🚀 Rachat LPP : 200k disponibles  │
│ ⚠️ 3a : 1 seul compte (sous-optimal)│
│ ✅ Versement : Max annuel         │
│ ❓ AVS : Lacunes non vérifiées    │
│                                    │
│ ACTIONS RECOMMANDÉES :             │
│ 1. Ouvre 2e compte 3a chez VIAC   │
│ 2. Planifie rachat LPP échelonné  │
│ 3. Commande extrait AVS           │
└────────────────────────────────────┘
```

---

### PHASE 4 : CERCLE 3 - CROISSANCE (Questions 21-25)

**Q21 : Patrimoine Immobilier**
```
Possèdes-tu un bien immobilier ?

[Non, locataire] [Oui, résidence principale] [Oui, + immeuble locatif]

SI Oui → Valeur estimée [Input]
SI Non → "Projet d'achat dans les 3 ans ?" [Oui/Non]
```

**Q22 : Investissements hors-pilier**
```
As-tu des investissements hors 3a/LPP ?

[ ] Actions/ETF
[ ] Crypto
[ ] Fonds/Obligations
[ ] Autre

Montant total estimé : [Input]

💡 Ordre logique :
1️⃣ Max 3a (déduction fiscale)
2️⃣ Rachat LPP (déduction fiscale)
3️⃣ PUIS investissements hors-pilier
```

**Q23 : Véhicule**
```
As-tu une voiture/moto ?

[Non] [Oui, totalement payée] [Oui, en leasing]

SI Leasing → Mensualité [Input]

💸 Alternative : Acheter d'occasion cash souvent 50% moins cher sur 5 ans
```

**Q24 : Objectif Principal**
```
Ton objectif financier principal ?

[Retraite confortable]
[Achat immobilier]
[Indépendance financière]
[Transmettre un héritage]
[Voyage/Projet personnel]

💡 Ton horizon défini ta stratégie :
• Retraite dans 16 ans → Équilibre sécurité/croissance
• Achat immo 2 ans → 100% épargne liquide
```

**Q25 : Tolérance Risque**
```
Face aux fluctuations de marché, tu es plutôt :

[Prudent] - Je dors mal si ça baisse de 10%
[Équilibré] - J'accepte du risque mesuré
[Dynamique] - Je vise le long terme, ça me va
```

**→ SCORE CERCLE 3 :**
```
┌────────────────────────────────────┐
│ 📈 CERCLE 3 - CROISSANCE : 40%    │
│                                    │
│ ✅ Pas d'immobilier locatif       │
│ ⚠️ Investissements : Non optimisés│
│ ❌ Leasing voiture : Coût élevé   │
│                                    │
│ RECOMMANDATIONS :                  │
│ 1. Termine leasing, achète cash   │
│ 2. Ouvre compte titres ETF (IB)   │
└────────────────────────────────────┘
```

---

## 📄 RAPPORT FINAL V2 - EXHAUSTIF

### Structure du Rapport

```
┌─────────────────────────────────────────────────────────────┐
│  PLAN MINT - Ton Plan Financier Personnalisé               │
│  Julien, 49 ans, Marié, Valais                             │
│  Généré le 18 janvier 2026                                 │
└─────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════
 📊 VUE D'ENSEMBLE
═══════════════════════════════════════════════════════════════

SCORE GLOBAL DE SANTÉ FINANCIÈRE : 72/100 - BON

┌──────────────────────────────┐
│ 🛡️ CERCLE 1 - PROTECTION    │ 85% ███████████ ░░
│ 💰 CERCLE 2 - PRÉVOYANCE     │ 65% ████████░░░░ 
│ 📈 CERCLE 3 - CROISSANCE     │ 40% █████░░░░░░░
│ 🏠 CERCLE 4 - OPTIMISATION   │ 20% ██░░░░░░░░░░
└──────────────────────────────┘

═══════════════════════════════════════════════════════════════
 💡 TES 3 ACTIONS PRIORITAIRES (Impact Maximum)
═══════════════════════════════════════════════════════════════

1. 🚀 OUVRE UN 2E COMPTE 3A CHEZ VIAC
   Gain fiscal au retrait : ~12'000 CHF

2. 💰 PLANIFIE TON RACHAT LPP ÉCHELONNÉ (200K SUR 4 ANS)
   Économie fiscale : ~60'000 CHF

3. ⚠️ VÉRIFIE TON COMPTE AVS (Lacunes possibles)
   Risque de perte : -160 CHF/mois de rente AVS

═══════════════════════════════════════════════════════════════
 📋 DÉTAIL PAR CERCLE
═══════════════════════════════════════════════════════════════

───────────────────────────────────────────────────────────────
 🛡️ CERCLE 1 : PROTECTION & SÉCURITÉ - 85%
───────────────────────────────────────────────────────────────

✅ Fonds d'urgence : OK
   • Tu as ~4 mois de charges de côté (estimation)
   • Cible idéale : 6 mois = 10'980 CHF (1830 loyer x 6)

✅ Dettes : Aucune
   • Pas de crédit conso ni leasing → Excellent !

✅ Revenu stable : 7'800 CHF/mois (ménage)

⚠️ LAMal : Franchise sous-optimale
   • Actuelle : 300 CHF (supposé)
   • Recommandé (profil sain) : 2'500 CHF
   • Économie prime : ~1'200 CHF/an

───────────────────────────────────────────────────────────────
 💰 CERCLE 2 : PRÉVOYANCE FISCALE - 65%
───────────────────────────────────────────────────────────────

✅ LPP : Affilié (salarié)

🚀 RACHAT LPP : OPPORTUNITÉ MAJEURE
   • Montant rachetable : 200'000 CHF
   • Âge : 49 ans → Retraite dans 16 ans
   
   STRATÉGIE OPTIMALE :
   ┌────────────────────────────────────────────┐
   │ Année │ Rachat   │ Économie Fiscale (VS)  │
   ├────────────────────────────────────────────┤
   │ 2026  │ 50'000   │ ~15'000 CHF            │
   │ 2027  │ 50'000   │ ~15'000 CHF            │
   │ 2028  │ 50'000   │ ~15'000 CHF            │
   │ 2029  │ 50'000   │ ~15'000 CHF            │
   ├────────────────────────────────────────────┤
   │ TOTAL │ 200'000  │ ~60'000 CHF ÉCONOMISÉS │
   └────────────────────────────────────────────┘

⚠️ 3A : SOUS-OPTIMAL
   • Comptes actuels : 1 (banque classique supposé)
   • Versement annuel : 7'258 CHF (max) ✅
   
   PROBLÈMES IDENTIFIÉS :
   1. UN SEUL COMPTE = Fiscalité retrait non optimisée
      → Perte estimée au retrait : ~12'000 CHF
   
   2. BANQUE CLASSIQUE = Frais élevés, rendement faible
      → Perte sur 16 ans vs VIAC : ~45'000 CHF
   
   RECOMMANDATION :
   ✅ Ouvre un 2e compte chez VIAC (stratégie 60% actions)
   ✅ Transfert ancien compte impossible → Garde-le, verse sur VIAC
   
   PROJECTION 16 ANS (7'258 CHF/an) :
   ┌──────────────────────────────────────────────┐
   │ Fournisseur      │ Frais│ Capital à 65 ans  │
   ├──────────────────────────────────────────────┤
   │ Banque actuelle  │ 1.2% │ CHF 130'000       │
   │ VIAC (60% act.)  │ 0.5% │ CHF 175'000       │
   ├──────────────────────────────────────────────┤
   │ GAIN VIAC        │      │ +45'000 CHF 🚀    │
   └──────────────────────────────────────────────┘

❓ AVS : Lacunes non vérifiées
   ⚠️ ACTION : Commande ton extrait de compte AVS
   → www.ahv-iv.ch (gratuit)
   → Si lacunes → Cotisations volontaires possibles

───────────────────────────────────────────────────────────────
 📈 CERCLE 3 : CROISSANCE - 40%
───────────────────────────────────────────────────────────────

✅ Immobilier : Aucun (locataire)
   • Loyer : 1'830 CHF/mois
   • Capacité achat : Non évalué (nécessite apport 20%)

⚠️ Investissements hors-pilier : Non renseignés
   RECOMMANDATION : Une fois Cercle 2 optimisé
   → Ouvre compte titres Interactive Brokers
   → ETF World (MSCI World) pour diversification

───────────────────────────────────────────────────────────────
 🏠 CERCLE 4 : OPTIMISATION & TRANSMISSION - 20%
───────────────────────────────────────────────────────────────

Non évalué (prioriser Cercles 1-3 d'abord)

═══════════════════════════════════════════════════════════════
 💸 SIMULATION FISCALE ANNUELLE
═══════════════════════════════════════════════════════════════

Revenu imposable (avant déductions) : 93'600 CHF

DÉDUCTIONS ACTUELLES :
• 3a (max) : -7'258 CHF

IMPÔTS ESTIMÉS (Valais, marié, 0 enfant) :
• Canton + Commune : ~12'500 CHF
• Confédération : ~3'200 CHF
• TOTAL : ~15'700 CHF/an (taux effectif 16.8%)

AVEC RACHAT LPP 50K (année 1) :
• Déduction supplémentaire : -50'000 CHF
• Impôts : ~4'500 CHF (économie ~11'200 CHF !)

═══════════════════════════════════════════════════════════════
 📅 ROADMAP PERSONNALISÉE
═══════════════════════════════════════════════════════════════

IMMÉDIAT (Ce mois)
│
├─ 1. Commande extrait compte AVS
├─ 2. Ouvre 2e compte 3a chez VIAC
├─ 3. Demande certificat LPP (montant rachetable exact)
│
COURT TERME (3-6 mois)
│
├─ 4. Planifie rachat LPP 2026 (50k CHF)
├─ 5. Optimise franchise LAMal (2500 CHF)
│
MOYEN TERME (6-12 mois)
│
├─ 6. Transfert progressif 3a vers VIAC
├─ 7. Rachat LPP 2027 (50k CHF)
│
LONG TERME (1-3 ans)
│
├─ 8. Rachats LPP 2028-2029 (100k CHF restants)
├─ 9. Évaluer projet immobilier si souhaité
└─ 10. Ouvre compte titres hors-pilier

═══════════════════════════════════════════════════════════════
 🎯 OBJECTIF RETRAITE (2041, 65 ans)
═══════════════════════════════════════════════════════════════

CAPITAL PRÉVOYANCE ESTIMÉ :

┌──────────────────────────────────────────────────┐
│ Source                │ Capital estimé           │
├──────────────────────────────────────────────────┤
│ LPP (actuel + rachats)│ CHF 850'000 (estimation) │
│ 3a (2 comptes)        │ CHF 175'000              │
│ AVS (rente viagère)   │ ~2'370 CHF/mois          │
├──────────────────────────────────────────────────┤
│ TOTAL CAPITAL         │ CHF 1'025'000            │
│ + Rente AVS           │ CHF 28'440/an à vie      │
└──────────────────────────────────────────────────┘

RENTE MENSUELLE ESTIMÉE (retraite) :
• LPP (6% de 850k) : 4'250 CHF/mois
• AVS : 2'370 CHF/mois
• TOTAL : ~6'600 CHF/mois

═══════════════════════════════════════════════════════════════
 📚 RESSOURCES & LIENS UTILES
═══════════════════════════════════════════════════════════════

OUVRIR UN 3A :
• VIAC : viac.ch (Le + fluide, app moderne)
• Finpension : finpension.ch (Le - cher, 0.39%)
• frankly : frankly.ch (Banque cantonale ZH)

RACHAT LPP :
• Guide complet : ch.ch/fr/rachat-lpp
• Simulateur : Credit Suisse / UBS (gratuit)

AVS :
• Extrait compte : ahv-iv.ch
• Lacunes : ch.ch/fr/lacunes-avs

OPTIMISATION FISCALE :
• Guide cantonal VS : vs.ch/web/scc/impots
• Calculateur impôts : comparis.ch/impots

═══════════════════════════════════════════════════════════════
 ⚠️ DISCLAIMERS
═══════════════════════════════════════════════════════════════

Les estimations sont à but pédagogique et basées sur :
• Hypothèses de rendement : 1-6% selon produit
• Fiscalité 2026 (Valais)
• Données partielles fournies

Pour des décisions engageantes :
→ Consulte un conseiller fiscal indépendant
→ Demande simulation personnalisée à ta caisse LPP
→ Vérifie les conditions exactes auprès des fournisseurs

═══════════════════════════════════════════════════════════════
```

---

## 🔧 IMPLÉMENTATION TECHNIQUE V2

### Modifications Requises

1. **Supprimer** : Questions confuses (budget_style mal expliqué)
2. **Auto-détecter** : LPP si salarié (skip question)
3. **Enrichir widgets** : Projections claires, durée, scénarios
4. **Réorganiser UI** : Question AVANT widget éducatif
5. **Rapport final** : Template exhaustif comme ci-dessus
6. **Scoring cercles** : Afficher % complétion par cercle

### Fichiers à Modifier

```
apps/mobile/lib/
├── data/wizard_questions.dart      [REFONTE TOTALE]
├── widgets/educational/
│   ├── tax_savings_insert_widget.dart [Ajouter projections]
│   └── lpp_buyback_insert_widget.dart [CRÉER]
├── services/
│   ├── report_builder_v2.dart      [CRÉER - Template exhaustif]
│   └── scoring_service.dart        [CRÉER - Calcul % par cercle]
└── screens/advisor/
    └── advisor_report_screen_v2.dart [REFONTE - Affichage rapport]
```

---

**Question** : Veux-tu que je commence par :
1. ✅ Refactoriser `wizard_questions.dart` avec ce flow V2 ?
2. ✅ Créer le service de scoring par cercles ?
3. ✅ Implémenter le template de rapport final exhaustif ?

Ou tout en une seule passe ?
