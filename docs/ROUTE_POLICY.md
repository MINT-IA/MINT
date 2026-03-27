# ROUTE POLICY

> Dernière mise à jour : 2026-03-27
> Statut : **AUTORITATIF** — Toute nouvelle route doit respecter ce document.
> Non-négociable : aucune nouvelle route legacy sans validation explicite.

---

## 1. État actuel

| Métrique | Valeur |
|---|---|
| Routes canoniques | **100** |
| Redirects legacy | **26** |
| Routes FR kebab-case | **67** (67%) |
| Routes EN kebab-case | **16** (16%) |
| Routes mixtes | **17** (17%) |

---

## 2. Règles pour les nouvelles routes

### Convention obligatoire

```
/{domaine}/{action-ou-sujet}
```

- **Langue** : français kebab-case (`/retraite/rachat`, pas `/retirement/buyback`)
- **Préfixe** : un des 7 domaines Explorer, ou un préfixe transversal autorisé
- **Pas de namespace technique** : pas de `/simulator/`, `/arbitrage/`, `/segments/`, `/life-event/`

### Préfixes autorisés

| Préfixe | Domaine | Exemples existants |
|---|---|---|
| `/retraite/` | Retraite & prévoyance | `/retraite`, `/retraite/rente-vs-capital` |
| `/famille/` | Famille & couple | `/divorce`, `/mariage`, `/naissance` |
| `/travail/` | Travail & statut | `/unemployment`, `/first-job` |
| `/logement/` | Logement & immobilier | `/hypotheque`, `/mortgage/*` |
| `/fiscalite/` | Fiscalité | `/fiscal` |
| `/patrimoine/` | Patrimoine & succession | `/succession` |
| `/sante/` | Santé & protection | `/invalidite`, `/assurances/*` |
| `/budget` | Budget (racine, accès fréquent) | `/budget` |
| `/dette/` | Prévention dette | `/debt/*` (legacy EN) |
| `/coach/` | Surfaces coach | `/coach/chat`, `/coach/history` |
| `/dossier/` | Profil & documents | `/profile/*` (legacy), `/documents` |
| `/onboarding/` | Parcours d'entrée | `/onboarding/smart`, `/onboarding/quick` |
| `/auth/` | Authentification | `/auth/login`, `/auth/register` |
| `/scan/` | Capture documentaire | `/scan`, `/scan/review` |
| `/outils/` | Simulateurs génériques | `/simulator/*` (legacy EN) |
| `/apprendre/` | Éducation | `/education/*` (legacy EN) |

### Ce qui est interdit

- Créer une route sous `/arbitrage/`, `/segments/`, `/3a-deep/`, `/lpp-deep/`, `/life-event/`, `/simulator/`
- Créer une route en anglais quand un équivalent FR existe
- Créer une route sans l'ajouter au `ScreenRegistry` si elle est routable par le coach
- Créer un redirect sans le documenter dans ce fichier

---

## 3. Routes legacy (freeze)

Les routes legacy suivantes existent et redirigent vers les routes canoniques. **Aucune nouvelle redirect ne doit être ajoutée sans justification.**

### Redirects actifs (26)

| Legacy | → Canonique | Catégorie |
|---|---|---|
| `/app/today` | `/home?tab=0` | Tab alias |
| `/app/coach` | `/home?tab=1` | Tab alias |
| `/app/explore` | `/home?tab=2` | Tab alias |
| `/app/dossier` | `/home?tab=3` | Tab alias |
| `/pulse` | `/home?tab=0` | Tab alias |
| `/coach/dashboard` | `/retraite` | Retraite |
| `/retirement` | `/retraite` | Retraite |
| `/retirement/projection` | `/retraite` | Retraite |
| `/arbitrage/rente-vs-capital` | `/rente-vs-capital` | Retraite |
| `/simulator/rente-capital` | `/rente-vs-capital` | Retraite |
| `/lpp-deep/rachat` | `/rachat-lpp` | Retraite |
| `/arbitrage/rachat-vs-marche` | `/rachat-lpp` | Retraite |
| `/lpp-deep/epl` | `/epl` | Retraite |
| `/coach/decaissement` | `/decaissement` | Retraite |
| `/arbitrage/calendrier-retraits` | `/decaissement` | Retraite |
| `/simulator/3a` | `/pilier-3a` | Fiscalité |
| `/mortgage/affordability` | `/hypotheque` | Logement |
| `/life-event/divorce` | `/divorce` | Famille |
| `/household` | `/couple` | Famille |
| `/household/accept` | `/couple/accept` | Famille |
| `/report` | `/rapport` | Patrimoine |
| `/report/v2` | `/rapport` | Patrimoine |
| `/disability/gap` | `/invalidite` | Santé |
| `/simulator/disability-gap` | `/invalidite` | Santé |
| `/document-scan` | `/scan` | Capture |
| `/document-scan/avs-guide` | `/scan/avs-guide` | Capture |
| `/advisor` | `/onboarding/quick` | Onboarding |
| `/advisor/wizard` | `/onboarding/quick` | Onboarding |
| `/onboarding/minimal` | `/onboarding/quick` | Onboarding |
| `/onboarding/enrichment` | `/profile/bilan` | Onboarding |
| `/ask-mint` | `/coach/chat` | Coach |
| `/coach/agir` | `/home` | Coach |
| `/weekly-recap` | `/coach/weekly-recap` | Coach |
| `/lpp-deep/libre-passage` | `/libre-passage` | Retraite |
| `/coach/succession` | `/succession` | Patrimoine |
| `/life-event/succession` | `/succession` | Patrimoine |

### Politique de suppression

Les redirects peuvent être supprimés en V2 (post-launch) si :
1. Aucun deep link externe ne les référence (notifications, emails, QR codes)
2. Le `ScreenRegistry` ne les utilise pas comme `intentTag` route
3. Aucun widget CTA ne les hardcode

---

## 4. Incohérences connues (dette acceptée)

| Route actuelle | Problème | Route idéale | Priorité de migration |
|---|---|---|---|
| `/profile/*` | Le tab s'appelle "Dossier" mais les routes sont sous `/profile` | `/dossier/*` | Basse — refactor big-bang, pas maintenant |
| `/mortgage/*` | Anglais sous un hub FR (Logement) | `/logement/*` | Basse |
| `/disability/*` | Anglais sous un hub FR (Santé) | `/sante/*` | Basse |
| `/3a-deep/*` | Namespace technique visible | `/retraite/3a-*` | Basse |
| `/debt/*` | Anglais | `/dette/*` | Basse |
| `/education/*` | Anglais | `/apprendre/*` | Basse |

**Politique** : ces incohérences sont documentées et acceptées. Elles seront migrées progressivement via alias (nouvelle route + ancien redirect), jamais en big-bang.

---

## 5. Checklist nouvelle route

Avant de créer une route :

- [ ] Le préfixe est dans la liste §2
- [ ] Le nom est en français kebab-case
- [ ] La route est ajoutée dans `app.dart` (GoRouter)
- [ ] La route est ajoutée dans `ScreenRegistry` (si routable par le coach)
- [ ] Les intent tags sont en snake_case anglais (convention interne)
- [ ] Aucun namespace legacy n'est réutilisé (`/arbitrage/`, `/simulator/`, etc.)
- [ ] Ce document est mis à jour si un nouveau préfixe est créé
