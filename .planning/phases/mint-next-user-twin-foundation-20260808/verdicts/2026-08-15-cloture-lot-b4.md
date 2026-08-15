# Verdict Codex — axe CLÔTURE du lot bascule 4 (2026-08-15, SHA 9deffc89a)

**NON FERMÉ.** Six constats. Quatre confirmaient ce qui était déjà écrit dans
le bail ; un cinquième portait sur une réserve déjà inscrite dans le test.

**Le sixième était neuf, et il portait sur mon travail** :
> Un test promet davantage que son corps. `legacy_onboarding_owner_test.dart`
> annonce « graphe transitif », mais vérifie une liste que le test a lui-même
> écrite. Un quatrième alias oublié resterait invisible.

Traité le jour même. Première tentative de correctif FAUSSE : elle exigeait
l'owner sur toute route sous préfixe legacy, et a échoué sur
`/onboarding/enrichment` — qui redirige vers `/profile/bilan`, pas vers le
wizard. Legacy par le nom, pas par la destination.

Version retenue : refus par défaut avec exceptions justifiées. Un alias ajouté
demain échoue tant que personne ne l'a motivé. Vérifié par mutation.

---

## Constats

1. **Le contrat de sortie se déclare lui-même incomplet.**  
   `product/mint_next/lego_lease.json:51-73` garde trois beats ouverts : `b4_reset_to_landing`, `b4_legacy_data_isolation` et `b4_cold_start_receipt`. Les deux derniers ont `preuve: null`. Or `:100-101` exige huit preuves réelles et un reçu cold-start lié au SHA. Scénario : une installation neuve peut encore emprunter un parcours jamais exécuté par le gate annoncé.

2. **La preuve runtime obligatoire n’existe pas.**  
   Le cadrage exige stockage vierge, aucun fixture/deeplink, kill/relaunch, reset et données historiques (`…bascule4-premiere-ouverture-cadrage-codex.md:33-35`). Les chemins réservés par le bail sont absents :
   - `tools/runtime/mint_next_first_open_lifecycle.sh`
   - `tools/simulator/flows/maestro-perfect-set/flow_mint_next_first_open_lifecycle.yaml`  
   Aucun reçu lié à `HEAD 9deffc89a` n’est fourni. Scénario : après CTA, l’app peut revenir sur la landing ou le wizard au redémarrage sans qu’aucun test ne le voie.

3. **L’isolation des anciennes données est actuellement violée.**  
   Le contrat interdit toute promotion silencieuse (`storyboard/first_open.storyboard.json:7`, cadrage `:25`). Pourtant `apps/mobile/lib/main.dart:50` appelle `TwinBootstrap.ensureMigrated()`, lequel charge les réponses via `ReportPersistenceService.loadAnswers()` (`twin_bootstrap.dart:55-58`) puis les migre. Le bail reconnaît cette violation (`lego_lease.json:64-67`). Scénario : une personne ayant rempli l’ancien wizard retrouve ces données transformées en faits du jumeau sans acte explicite.

4. **Un test promet davantage que son corps.**  
   `legacy_onboarding_owner_test.dart:17-29` annonce « transitive route graph », mais vérifie une liste écrite par le test lui-même : `/onb`, `/start`, `/anonymous/chat` (`:25`). Un quatrième alias oublié resterait invisible à cet oracle. Le vrai graphe relève du script, pas de ce test (`:21-24`).

5. **Le test lifecycle ne prouve pas la relance annoncée.**  
   `first_open_lifecycle_test.dart:15-20` l’admet explicitement : `setMockInitialValues()` ne traverse pas une frontière de processus. Pourtant le nom commence par « a relaunch » (`:67-69`). Scénario : SharedPreferences fonctionne dans le test tandis que le stockage réel ou l’ordre de bootstrap diverge après kill.

6. **Le lot dépasse massivement son cadrage.**  
   175 fichiers et 23 663 insertions couvrent fiscalité, 3a, registre communal, backend et jumeau. Le bail lui-même mesure 78 commits étrangers et impose une reconstruction sémantique depuis `dev` (`lego_lease.json:150-166`). Cette branche n’est donc pas une unité B4 relisible ou promouvable.

## Ordre de traitement

1. Supprimer la promotion silencieuse et prouver conservation, non-reprise et non-suppression des données historiques.
2. Écrire puis exécuter le vrai parcours cold-start Maestro, kill/relaunch inclus.
3. Produire le reçu lié au SHA avec trace ordonnée des owners et empreinte du registre.
4. Obtenir le verdict Codex dédié à `b4_reset_to_landing`.
5. Reconstruire B4 depuis `dev`, puis exécuter les quatre gates d’acceptation.

# **NON FERMÉ**

## Key Learnings:

1. Un test nommé « graphe transitif » reste faible s’il énumère manuellement les routes connues.
2. La branche B4 transforme silencieusement des données wizard historiques via le bootstrap du jumeau.
3. Aucun test avec SharedPreferences simulées ne remplace une preuve de relance réelle.
tokens used
83,182
## Constats

1. **Le contrat de sortie se déclare lui-même incomplet.**  
   `product/mint_next/lego_lease.json:51-73` garde trois beats ouverts : `b4_reset_to_landing`, `b4_legacy_data_isolation` et `b4_cold_start_receipt`. Les deux derniers ont `preuve: null`. Or `:100-101` exige huit preuves réelles et un reçu cold-start lié au SHA. Scénario : une installation neuve peut encore emprunter un parcours jamais exécuté par le gate annoncé.

