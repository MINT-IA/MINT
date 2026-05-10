---
description: Expert 6 — Swiss + EU compliance read sur le pivot « calc engine = source of truth, LLM = illumination ». Évalue si le pivot rend MINT plus défendable sous LSFin / FINMA Guidance 08/2024 / ESMA AI Statement 2024 / MiFID II que l'architecture précédente « LLM-narrator-with-tool-calls ». Trois questions, trois propositions roadmap, un contre-argument.
status: Proposed
audience: Product Leader (Julien) + équipe juridique externe (à briefer)
date: 2026-05-09
counter_arguments: §6
data_gaps: §7
---

# Expert 6 — Compliance Swiss-Brain : pivot calc-first vs LSFin / FINMA Guidance 08/2024

## 0. Contexte

Le 2026-05-09, l'éval Stage 3 du LLM-narrator MINT a montré des échecs structurels sur `numbers_traceable` : des chiffres apparaissaient dans la sortie sans pouvoir être rattachés mécaniquement à un calcul déterministe. Décision pivot proposée : **« calc engine = source of truth, LLM = illumination »**. Concrètement :

- `apps/mobile/lib/services/financial_core/` (LPP, AVS, fiscalité art. 38 LIFD, arbitrage, FRI, housing, Monte-Carlo) reste seul producteur de chiffres.
- Le LLM ne peut **plus inventer** de nombres ; il reçoit en entrée un objet `CalcResult` (avec `traceId`, hypothèses, `EnhancedConfidence` 4 axes) et produit du langage qui **éclaire** les chiffres déjà calculés.
- L'output rendu à l'utilisateur final est le couple `(CalcResult déterministe, narration LLM bornée par template)`.

La question soumise à ce panel : ce pivot rend-il MINT **plus** ou **moins** défendable sous LSFin (FinSA), LIFD art. 38, FINMA Guidance 08/2024, ESMA Public Statement on AI 2024 et MiFID II ?

Réponse synthétique : **plus défendable, mais à condition de boucler trois pièces concrètes** (audit-trail, disclaimer in-app, registre des modèles). Le contre-argument tribunal-strict (§6) doit être pris au sérieux : un système entièrement déterministe et personnalisé peut être requalifié en « conseil en placement » par un juge moins regardant sur la marketing-line « éclairage ». La défense ne tient que si l'architecture **ET** le wording **ET** la documentation racontent la même histoire.

---

## 1. Question 1 — Le pivot rend-il MINT plus défendable sous LSFin ?

### 1.1 Ce que dit la loi

**LSFin / FinSA art. 3 let. c** définit les services financiers couverts. Le « conseil en placement » (`ch. 4`) et la « gestion de fortune » (`ch. 3`) sont les deux périmètres durs ; ils déclenchent l'art. 11 (suitability) et art. 12 (appropriateness) FinSA, l'obligation de KID (art. 8), de documentation (art. 15), de reddition de compte (art. 16) et la responsabilité civile élargie (art. 69-71).

L'art. 3 let. c ch. 4 LSFin parle de « **recommandation personnalisée d'opérations sur instruments financiers** ». Trois éléments cumulatifs :

1. **Recommandation** (≠ information neutre).
2. **Personnalisée** (≠ générique, basée sur la situation du client).
3. **Sur instruments financiers** (titres, fonds, dérivés, structurés, dépôts collectifs — art. 3 let. a LSFin).

MINT ne touche pas au point 3 dans son périmètre actuel : aucun ordre, aucun produit financier vendu, aucun acheminement vers une plateforme de trading. Le risque réside dans 1 et 2 : la « narration LLM » d'avant-pivot pouvait, par hallucination, glisser d'« éclairage générique » vers « tu devrais retirer X CHF de ton 3a en 2027 » — recommandation personnalisée, même sans instrument financier au sens art. 3 let. a.

### 1.2 Pourquoi le pivot calc-first **renforce** la défense

Trois mouvements simultanés :

**(a) Traçabilité mécanique des nombres.** FINMA Guidance 08/2024 (publié 18 décembre 2024, entré en vigueur début 2025) impose un **niveau d'explicabilité gradué** : « high-impact decisions affecting individual customers […] demand the highest level of explainability, including the ability to identify specific factors that influenced the outcome » ([MLL News Portal — FINMA Guidance 08/2024](https://www.mll-news.com/finma-guidance-08-2024-governance-and-risk-management-when-using-artificial-intelligence/?lang=en)). Avec calc-first, chaque chiffre rendu à l'utilisateur a un `traceId` pointant vers `LppCalculator.computeMonthlyRente()` ou `TaxCalculator.computeArt38Lifd()` — formule, paramètres, version du code, hypothèses. Aucun chiffre LLM = aucun chiffre inexpliquable. C'est **exactement** la définition d'explicabilité que FINMA réclame.

**(b) Reproductibilité.** L'éval Stage 3 a montré que le LLM-narrator pouvait produire deux fois des chiffres différents pour le même profil. C'est la pire situation possible sous FINMA Guidance 08/2024 §III « robust and reliable systems ». Un calcul déterministe est par construction reproductible ; deux runs sur le même `Profile` produisent le même `CalcResult` au centime près. Cela répond directement à l'exigence FINMA de « robustness ».

**(c) Frontière LSFin claire.** L'art. 3 al. 3 let. b FinSO (ordonnance d'exécution LSFin) et la nouvelle Circulaire FINMA 2025/2 (entrée en vigueur 1er janvier 2025, [Pestalozzi](https://pestalozzilaw.com/en/insights/news/legal-insights/new-finma-circular-20252-on-rules-of-conduct-under-finsafinso/)) clarifient le périmètre des services financiers. L'« information générale » à but éducatif, sans recommandation personnalisée d'instrument financier, reste hors-LSFin. Le pivot calc-first le formalise : **le LLM ne génère plus de chiffres**, donc il ne peut plus, par hallucination, basculer dans la recommandation personnalisée. Sa fonction se réduit à de la pédagogie sur des chiffres déjà calculés (« voici ce que ton 3a peut représenter à 65 ans selon les hypothèses X et Y »), ce qui correspond à l'exception d'information générale.

### 1.3 Comparaison avec « LLM-as-narrator-with-tool-calls »

| Axe | Narrator-with-tools (ancien) | Calc-first illumination (pivot) |
|---|---|---|
| Source des chiffres | LLM peut générer des nombres entre les tool-calls | Calc engine seul, chiffres immuables passés au LLM |
| Hallucination de chiffre | Possible (Stage 3 prouvé) | Impossible par construction (templating strict) |
| `traceId` par chiffre | Optionnel, parfois manquant | Mécaniquement obligatoire |
| Explicabilité FINMA | « best effort » | Auditable formule par formule |
| Reproductibilité | Stochastique | Déterministe |
| Risque LSFin recommandation perso | Moyen (LLM dérive) | Faible (LLM ne touche plus aux chiffres) |
| Charge documentaire | Lourde (chaque prompt à versionner) | Allégée (calculs versionnés via git, prompts brefs) |

**Conclusion §1 : oui, le pivot rend MINT plus défendable** — à condition que l'audit-trail (proposition 3.1) soit câblé et que le wording UI ne re-bascule pas en « conseil » par mégarde (proposition 3.3).

Articles cités : LSFin (FinSA) art. 3 let. c, art. 8, art. 11, art. 15, art. 16, art. 69-71 ; FinSO art. 3 al. 3 let. b ; Circulaire FINMA 2025/2 « Règles de comportement LSFin/OSFin » ; FINMA Guidance 08/2024 §II-III (gouvernance, explicabilité, robustesse).

---

## 2. Question 2 — Top regulatory reference / circular pour cadrer la position MINT

### Référence top-1

**FINMA Guidance 08/2024 — « Governance and risk management when using artificial intelligence »**, publiée 18 décembre 2024.

URL officielle : <https://www.finma.ch/en/news/2024/12/20241218-mm-finma-am-08-24/>

Take-away en 1 ligne : **« Les institutions financières utilisant l'IA doivent garantir une explicabilité graduée à l'impact, une robustesse mesurable et une documentation traçable de chaque décision affectant le client » — c'est exactement le contrat que le pivot calc-first signe par construction architecturale.**

### Référence top-2 (à citer en complément)

**ESMA Public Statement on AI and Investment Services** (30 mai 2024), <https://www.esma.europa.eu/sites/default/files/2024-05/ESMA35-335435667-5924__Public_Statement_on_AI_and_investment_services.pdf>.

Take-away : ESMA exige que les firmes utilisant l'IA en services d'investissement respectent les obligations MiFID II « organisational, conduct of business, best interest of the client », même si l'IA n'est qu'un outil interne. Pour MINT : informer l'utilisateur qu'un algorithme déterministe (et un LLM auxiliaire) participe au rendu, et préciser leur rôle.

### Référence top-3

**Circulaire FINMA 2025/2 « Règles de comportement LSFin/OSFin »** (entrée en vigueur 1er janvier 2025, transition 30 juin 2025), <https://pestalozzilaw.com/en/insights/news/legal-insights/new-finma-circular-20252-on-rules-of-conduct-under-finsafinso/>.

Take-away : la circulaire clarifie la frontière entre « investment advice for individual transactions » (art. 11 FinSA) et services hors-périmètre. Pour MINT : confirme que l'éducation financière sans recommandation d'instrument financier reste hors-scope, mais le wording doit être irréprochable.

---

## 3. Trois compliance moves concrets à locker AVEC le pivot

### 3.1 Audit-trail mécanique côté `financial_core` + ConfidenceScorer

**Quoi.** Chaque sortie utilisateur portant un chiffre (rente AVS projetée, capital 3a à 65, impôt art. 38 LIFD sur retrait LPP, scénario FRI…) doit embarquer un `CalcTrace` :

```dart
class CalcTrace {
  final String traceId;            // uuid v4, persisté + loggable
  final String calculatorId;       // ex. "lpp_calculator.computeMonthlyRente#v3.2.1"
  final Map<String, dynamic> inputs;     // copie immuable des inputs (sans PII)
  final Map<String, dynamic> assumptions; // taux conversion LPP, taux d'intérêt, etc.
  final EnhancedConfidence confidence;    // 4 axes existants
  final DateTime computedAt;
  final String formulaRef;         // ex. "LPP art. 14, conversion rate 6.0%"
  final String legalRef;           // ex. "LIFD art. 38 al. 2"
}
```

**Pourquoi.** FINMA Guidance 08/2024 §III « Documentation » + ESMA Statement §4 « organisational requirements » exigent que l'institution puisse, sur demande de l'auditeur ou du client, **expliquer chaque chiffre**. Le `CalcTrace` est cette preuve mécanique, versionnable via git (le `calculatorId` inclut la version du module).

**Impact code (déjà partiellement présent).** `lib/services/financial_core/confidence_scorer.dart` produit déjà `EnhancedConfidence` 4 axes. Il manque : (a) `traceId` propagation jusqu'au widget UI, (b) `legalRef` par calculator, (c) endpoint `GET /trace/:id` sur backend pour rejouer le calcul (déterminisme = rejouable).

**Verify.** Test golden : pour Julien-archetype `swiss_native` âge 42 année 2026, `LppCalculator.computeMonthlyRente()` produit deux fois la même valeur **et** le même `traceId.calculatorId` ; le `formulaRef` non vide ; le `legalRef` cite un article de loi réel.

### 3.2 Registre des modèles + version-pinning du LLM

**Quoi.** Un fichier `docs/COMPLIANCE/AI_MODEL_REGISTRY.md` (ou `.planning/compliance/ai_model_registry.md`) qui liste :

- Pour chaque calculator déterministe : `id`, version sémantique, dernière revue actuarielle, jeu de tests golden référent, articles de loi suisses couverts, date de dernière vérification de paramètres (taux LPP, barèmes LIFD, plafonds 3a).
- Pour le LLM narrator : provider, modèle exact (`claude-opus-4-7@2026-XX-XX`), température (0 idéalement), prompt template hashé (SHA256), liste des inputs autorisés (= `CalcResult` + profil non-PII), output schema (templating strict, pas de chiffre brut sortant du LLM), test-set d'éval (Stage 3 + suivants).

**Pourquoi.** FINMA Guidance 08/2024 §II.2 « inventory of AI applications » : **le registre est explicitement requis**. Lenz & Staehelin résume : « FINMA expects each financial institution to maintain a complete inventory of AI applications, classified by risk level » ([Lenz & Staehelin — FINMA Issues Guidance on AI Use](https://www.lenzstaehelin.com/news-and-insights/browse-thought-leadership-insights/insights-detail/finma-issues-guidance-on-ai-use-in-financial-institutions/)). MINT n'est pas (encore) une institution surveillée FINMA, mais le jour où un partenariat banque/assurance arrive, ce registre devient un asset commercial — et son absence un blocker.

**Impact organisationnel.** Le registre vit dans `.planning/compliance/` ; un check pre-commit (`tools/checks/`) refuse une bump de version d'un calculator si la ligne du registre n'a pas été mise à jour.

**Verify.** Lint script qui parse `lib/services/financial_core/*.dart` et confirme qu'il existe une entrée registre pour chaque classe `*Calculator` avec `legalRef` non vide.

### 3.3 In-app disclaimer + wording éclairage gating LLM output

**Quoi.** Trois pièces UX/copy :

1. Un écran « Comment MINT calcule » accessible depuis chaque chiffre affiché (tap sur un nombre → bottom-sheet avec `CalcTrace` lisible : formule, hypothèses, articles de loi cités, niveau de confiance 4 axes).
2. Un disclaimer LSFin systématique en pied d'écran sur tout résultat chiffré : « MINT propose un éclairage éducatif basé sur des calculs déterministes. Ce n'est pas un conseil en placement au sens de la LSFin (FinSA) art. 3. Pour une décision impliquant un instrument financier, consultez un prestataire agréé. »
3. Un guard côté LLM qui **rejette** toute sortie contenant : un chiffre absent du `CalcResult` injecté, un terme banni (cf. liste CLAUDE.md §1), ou un verbe directif (« retirez », « investissez », « achetez », « vendez ») suivi d'un instrument financier.

**Pourquoi.** L'art. 3 let. c LSFin requiert recommandation **personnalisée** sur instrument **financier** pour entrer dans le scope. Le wording « éclairage » + le guard LLM + le disclaimer signalent au régulateur ET au juge que MINT a explicitement renoncé à ce périmètre. Sans ces trois pièces, la défense « éclairage pas conseil » devient une assertion marketing non documentée. Avec elles, c'est une posture architecturale prouvable.

**Verify.** Test widget : pour 5 archetypes × 18 life events, capturer la fin d'écran et vérifier mécaniquement présence du disclaimer + accessibilité du sheet `CalcTrace`. Test prompt-eval : 200 prompts adversariaux tentent de forcer le LLM à dire « retirez votre 3a maintenant » ; taux d'évasion attendu = 0%.

---

## 4. Trois propositions concrètes pour la roadmap

### Proposition A — `CalcTrace` propagé jusqu'au widget (3-4 jours dev)

**Surface.** `lib/services/financial_core/*.dart` (ajouter `CalcTrace` au retour de chaque calculator) + `lib/widgets/confidence/` (ajouter bouton « Comment c'est calculé » qui ouvre bottom-sheet) + 2 endpoints backend FastAPI (`GET /trace/:id`, `POST /replay-calc`).

**Verify.** Golden tests sur Julien et Lauren ; widget test sur 5 écrans clés ; pytest backend `test_replay_calc_deterministic`.

**LSFin ROI.** Boucle l'explicabilité FINMA Guidance 08/2024 §III pour la branche calc.

### Proposition B — `AI_MODEL_REGISTRY.md` + lint pre-commit (1 jour dev)

**Surface.** Crée `.planning/compliance/ai_model_registry.md` template ; script `tools/checks/ai_registry_lint.py` ; hook lefthook ; un `legalRef:` champ obligatoire sur chaque calculator.

**Verify.** Lint exit 0 sur main ; CI bloque une PR qui modifie un calculator sans bump registre.

**LSFin ROI.** Boucle FINMA Guidance 08/2024 §II.2 (inventory). Asset commercial pour due-diligence partenaires.

### Proposition C — LLM output guard + disclaimer systémique (2-3 jours dev)

**Surface.** `services/backend/app/services/llm_narrator/` ajouter `output_guard.py` (rejette chiffre hors-CalcResult, terme banni, verbe directif + instrument) ; `apps/mobile/lib/widgets/disclaimers/lsfin_disclaimer.dart` ajouté à `MintScaffold` pour tout écran de calcul ; ajout au `mint-swiss-compliance` skill d'un test adversarial loop (200 prompts, taux d'évasion = 0%).

**Verify.** `python3 -m pytest services/backend/tests/test_llm_output_guard.py -q` (200 cas adversariaux verts) ; `flutter test apps/mobile/test/widgets/lsfin_disclaimer_test.dart` ; `check_banned_terms()` MCP scan sur 100 outputs LLM samples.

**LSFin ROI.** Verrouille la frontière LSFin art. 3 let. c. Sans ce guard, les propositions A et B ne suffisent pas — le LLM peut toujours dériver et faire tomber MINT dans le scope par accident.

---

## 5. Citations détaillées (≥4)

1. **FINMA Guidance 08/2024**, FINMA, 18 décembre 2024 — explicabilité graduée, robustesse, gouvernance, inventory AI. <https://www.finma.ch/en/news/2024/12/20241218-mm-finma-am-08-24/>
2. **MLL News Portal**, analyse Guidance 08/2024 : « high-impact decisions […] demand the highest level of explainability ». <https://www.mll-news.com/finma-guidance-08-2024-governance-and-risk-management-when-using-artificial-intelligence/?lang=en>
3. **ESMA Public Statement on AI in investment services**, ESMA35-335435667-5924, 30 mai 2024 — MiFID II conduct of business + best interest of client. <https://www.esma.europa.eu/sites/default/files/2024-05/ESMA35-335435667-5924__Public_Statement_on_AI_and_investment_services.pdf>
4. **Circulaire FINMA 2025/2 « Règles de comportement LSFin/OSFin »**, FINMA, 22 novembre 2024, entrée en vigueur 1er janvier 2025. Analyse Pestalozzi : <https://pestalozzilaw.com/en/insights/news/legal-insights/new-finma-circular-20252-on-rules-of-conduct-under-finsafinso/>
5. **Lenz & Staehelin** — synthèse pratique Guidance 08/2024, registre AI obligatoire. <https://www.lenzstaehelin.com/news-and-insights/browse-thought-leadership-insights/insights-detail/finma-issues-guidance-on-ai-use-in-financial-institutions/>
6. **Academy & Finance** — « Conseil en placement et LSFin : quels process précis ». Frontière conseil en placement vs information. <https://www.academyfinance.ch/conseil-en-placement-et-lsfin-quels-process-precis-pour-bien-repondre-a-toutes-les-exigences-legales/>
7. **LIFD art. 38** — imposition séparée à 1/5 du taux ordinaire des prestations en capital de prévoyance. Analyse 2026 : <https://invexa.ch/fr/prevoyance/impot-sur-le-retrait-du-2eme-pilier-lpp/>

---

## 6. Counter-argument — quand « calc = source of truth » BACKFIRE

> Un panel honnête doit nommer le scénario où sa propre recommandation se retourne. Le voici.

### 6.1 Le risque de requalification

Un juge cantonal (ex. tribunal civil de Lausanne sur un litige consommateur) lit l'art. 3 let. c ch. 4 LSFin et la Circulaire FINMA 2025/2. Il observe :

1. MINT collecte la situation patrimoniale complète (8 archetypes, 18 life events, profil détaillé).
2. MINT calcule **de manière déterministe** ce que représente un retrait 3a partiel en 2027 vs 2028 vs 2029, avec impact fiscal art. 38 LIFD au centime près.
3. MINT affiche un scénario chiffré, signé par un `traceId`, avec niveau de confiance, référence légale, et formule.
4. L'utilisateur prend la décision sur cette base ; le retrait fiscal s'avère sous-optimal car un canton voisin offrait un meilleur barème non simulé.

Le juge peut raisonner : *« précisément parce que c'est déterministe, traçable, personnalisé et signé, c'est plus fiable qu'un conseil humain — donc c'est de facto un conseil en placement, et MINT engage sa responsabilité art. 11 FinSA pour défaut de suitability check ».*

C'est la **trap de la sur-personnalisation déterministe**. L'argument « le LLM hallucine donc c'est juste de l'inspiration » ne tient plus quand le calc engine est rigoureux.

### 6.2 Pourquoi le risque est réel mais gérable

Trois éléments défensifs :

- **Pas d'instrument financier au sens art. 3 let. a LSFin.** MINT ne recommande pas un fonds, une action, un produit structuré. Il calcule des projections fiscales et patrimoniales sur des dispositifs légaux suisses (LPP, AVS, 3a, fiscalité). L'art. 3 let. c ch. 4 LSFin requiert l'instrument financier comme objet de la recommandation. C'est la défense principale.
- **Pas de recommandation « buy/sell/hold »**, juste une projection sous hypothèses éditables. La proposition C (guard LLM + verbes bannis) verrouille ce point.
- **Disclaimer + écran « Comment c'est calculé »** = aveu architectural que MINT ne fait pas de suitability art. 11 FinSA. La proposition C fournit la preuve.

### 6.3 Mitigation supplémentaire (au-delà des 3 propositions)

Avant TestFlight grand public : **opinion légale écrite** d'un cabinet suisse spécialisé (Lenz & Staehelin, Pestalozzi, Bär & Karrer, Walder Wyss) sur le périmètre LSFin de MINT post-pivot calc-first. Coût indicatif CHF 8-15k pour un memo de 10-15 pages. Cet asset (a) protège en cas de litige, (b) débloque les partenariats banque/assurance qui le demanderont, (c) valide ou invalide ce panel par une autorité externe. **C'est le seul check externe qui transforme le pivot d'« hypothèse compliance » en « position défendable certifiée ».**

---

## 7. Data gaps

- **Pas de jurisprudence cantonale récente** trouvée sur la frontière éducation financière vs conseil en placement post-LSFin (2020+). À demander au cabinet retenu en 6.3.
- **Position de la SFAMA / Swiss Bankers Association** sur les apps fintech éducatives : pas couverte par les recherches WebSearch ; à investiguer via la FAQ ASB de février 2025.
- **EU AI Act application extraterritoriale** sur MINT (utilisateur frontalier France, expat US/EU) : FINMA Guidance 08/2024 mentionne l'effet extraterritorial mais ne tranche pas le statut d'une app suisse hébergée en CH consommée par un résident UE. À traiter avant launch UE éventuel.
- **Test adversarial loop sur LLM-narrator** : la barre « 0% évasion » de la proposition C est exigeante ; pas de benchmark interne à ce jour. À calibrer dans le premier sprint d'implémentation.
- **Coût mémoire/perf** du `CalcTrace` propagé sur device (mobile) : pas mesuré ; risque mineur mais à valider sur Pixel low-end et iPhone SE.

---

## 8. Verdict

| Question | Réponse |
|---|---|
| Q1 — Pivot rend MINT plus défendable LSFin ? | **Oui**, à condition d'implémenter les 3 propositions A/B/C. Sans elles, le pivot est marketing. Avec elles, c'est une posture architecturale prouvable. |
| Q2 — Top reference ? | **FINMA Guidance 08/2024** + ESMA Statement 30 mai 2024 + Circulaire FINMA 2025/2 (triplet à citer ensemble). |
| Q3 — 3 compliance moves ? | A. `CalcTrace` propagé. B. `AI_MODEL_REGISTRY.md` + lint. C. LLM output guard + disclaimer in-app + écran « Comment c'est calculé ». |

**Recommandation finale au Product Leader.** Engager les 3 propositions sur les 2 prochaines semaines, **et** mandater une opinion légale externe (§6.3) avant TestFlight grand public. Le pivot calc-first est compliance-positive net, mais sa valeur juridique se réalise uniquement quand l'audit-trail, le registre et le guard sont en production — et qu'un cabinet suisse a écrit que la position tient.
