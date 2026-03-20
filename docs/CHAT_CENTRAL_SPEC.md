# MINT Chat Central — Spec d'implémentation

> Le chat n'est pas une feature de MINT. Le chat EST MINT.
> Tout passe par là : onboarding, profil, arbitrages, widgets, plan.

---

## 1. Principe

L'utilisateur ouvre MINT. Il voit le coach. Il parle. Tout se construit.

Pas de formulaire séparé. Pas d'écran d'onboarding. Pas de profile screen à remplir.
Le coach pose les questions au bon moment, montre les widgets quand c'est pertinent,
et construit le profil en arrière-plan.

---

## 2. Les 3 modes du chat

### Mode 1 — Onboarding conversationnel
Le coach guide le nouvel utilisateur en 3 questions :
- "Quel âge as-tu ?"
- "Ton revenu brut annuel ?"
- "Tu vis dans quel canton ?"
→ Premier widget inline (ChatComparisonCard retraite)
→ Profil créé en arrière-plan

### Mode 2 — Enrichissement progressif
Le coach demande des infos supplémentaires AU BON MOMENT :
- Quand on parle retraite : "Tu as un certificat LPP ?"
- Quand on parle couple : "Tu es marié ?"
- Quand on parle budget : "Ton loyer, c'est combien ?"
→ Le profil s'enrichit naturellement
→ La confiance monte

### Mode 3 — Exploration et arbitrage
L'utilisateur pose des questions, le coach montre des widgets :
- "Combien à la retraite ?" → ChatComparisonCard
- "Rente ou capital ?" → ChatChoiceComparison
- "Mon score ?" → ChatGaugeCard
- "Combien d'impôts en moins avec le 3a ?" → ChatFactCard
→ Chaque widget est tappable pour aller plus loin

---

## 3. Claude Tools pour la saisie de profil

### Tools existants (widgets)
- show_retirement_comparison
- show_budget_overview
- show_score_gauge
- show_fact_card
- show_choice_comparison
- show_pillar_breakdown

### Nouveaux tools (saisie)
```
ask_user_age → demander l'âge (inline picker)
ask_user_salary → demander le revenu (numeric keyboard)
ask_user_canton → demander le canton (picker 26 cantons)
ask_user_civil_status → demander le statut marital
ask_user_employment → demander le statut d'emploi
ask_user_children → demander le nombre d'enfants
request_document_scan → inviter à scanner un document (LPP, AVS)
update_profile → mettre à jour un champ du profil
```

### Comment ça marche
1. Claude analyse la conversation
2. Il décide qu'il a besoin d'une info (ex: canton manquant)
3. Il appelle `ask_user_canton` avec un message contextuel
4. Flutter affiche un picker inline dans le chat
5. L'utilisateur sélectionne
6. Le profil est mis à jour via CoachProfileProvider
7. Le coach continue avec la nouvelle info

---

## 4. Voix du coach

### Personnalité
- Calme, pas bavard
- Précis, pas technique
- Fin, pas drôle
- Rassurant, pas condescendant
- Net, pas brutal

### Patterns de conversation

Onboarding :
> "Salut. Pour te donner un premier aperçu, j'ai besoin de 3 choses."
> "Quel âge as-tu ?"
> [picker inline]
> "Et ton revenu brut annuel ?"
> [champ numérique]
> "Dernier truc : tu vis dans quel canton ?"
> [picker cantons]
> [Widget: CHF 4'416/mois — 63% de ton train de vie]
> "Voilà ton premier aperçu. On approfondit ?"

Enrichissement :
> "Au fait — ton certificat LPP rendrait cette estimation bien plus précise."
> [Bouton: Scanner mon certificat]

Arbitrage :
> "63% — c'est ce que tu gardes. Le 2e pilier porte la moitié."
> [Widget: comparaison AVS/LPP/3a]
> "Un rachat LPP pourrait changer la trajectoire. On simule ?"

### Ce que le coach ne fait JAMAIS
- Parler pour ne rien dire ("Voici ta situation financière")
- Célébrer artificiellement ("Bravo ! Excellent travail !")
- Donner des conseils ("Tu devrais ouvrir un 3a")
- Promettre ("Garanti", "Optimal", "Meilleur")

---

## 5. Architecture technique

### Flow
```
User input → Flutter sends to Backend
→ Backend injects: system prompt + profile + CapMemory + tools (widgets + saisie)
→ Claude responds with: text + tool_use (widget OR saisie)
→ Backend returns: {reply, widget?, input_request?}
→ Flutter renders: coach bubble + widget inline OR input picker inline
→ Si input_request: user répond → profile updated → chat continue
```

### System prompt enrichi
Le system prompt inclut :
- Voix MINT (5 piliers)
- Profil complet de l'utilisateur
- Ce qui manque dans le profil (champs vides)
- CapMemory (actions complétées, flows abandonnés)
- financialLiteracyLevel
- Instruction : "Si tu as besoin d'une info manquante, utilise le tool ask_user_*"

### Nouveaux composants Flutter
```
ChatInlinePicker — CupertinoPicker dans une bulle chat
ChatInlineNumericInput — champ numérique avec format CHF live
ChatInlineCantonPicker — grille des 26 cantons
ChatInlineConfirmation — bouton "C'est bon" / "Modifier"
```

---

## 6. Quick Start via chat

L'écran Quick Start actuel devient OPTIONNEL.
Le flow par défaut est :

1. User ouvre MINT pour la première fois
2. Landing page (V10)
3. Tap "Commencer"
4. → Arrive directement dans le Coach chat
5. Le coach fait l'onboarding conversationnel
6. Après 3 inputs → premier widget → profil créé
7. → Aujourd'hui se remplit automatiquement

---

## 7. Ordre d'implémentation

### Phase 1 — Chat comme onboarding
- Claude tools : ask_user_age, ask_user_salary, ask_user_canton
- Flutter : ChatInlinePicker, ChatInlineNumericInput
- Le coach détecte un profil vide et lance l'onboarding
- Landing → Coach directement

### Phase 2 — Chat comme enrichissement
- Claude tools : ask_user_civil_status, ask_user_children, request_document_scan
- Le coach demande au bon moment (lié au sujet de conversation)
- Confidence score monte après chaque saisie

### Phase 3 — Chat comme centre d'arbitrage
- Rich widgets déjà créés (ChatComparisonCard, etc.)
- Claude choisit le bon widget via tool calling
- Chaque widget tappable → écran de détail

---

## 8. Phrase directrice

**L'utilisateur ne navigue plus. Il parle. MINT lui répond avec des chiffres vivants.**
