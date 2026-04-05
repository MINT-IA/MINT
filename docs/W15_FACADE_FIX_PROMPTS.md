# W15 — Sprint Façade sans câblage (11 fils déconnectés)

> Ce document contient les prompts pour CONNECTER les 11 façades
> identifiées par la Wave 15. Chaque prompt câble un flux end-to-end.
>
> **Vague 1** : Prompts 1, 2, 3 (P0 — impact utilisateur direct)
> **Vague 2** : Prompts 4, 5, 6 (P1 — features dégradées)
> **Vague 3** : Prompts 7, 8 (P2 — infrastructure morte)

---

## PROMPT 1 — Profile Sync : câbler claimLocalData() (P0)

```
Tu es un ingénieur full-stack senior. Tu câbles UN fil critique :
les profils utilisateurs ne sont JAMAIS syncés au backend.

## CONTEXTE
- Branche : feature/w15-wire-profile-sync
- Run flutter analyze + flutter test + pytest tests/ -q AVANT et APRÈS

## LE PROBLÈME
`ApiService.claimLocalData()` existe (api_service.dart ~ligne 1070) mais a
ZÉRO appels dans tout le codebase. Les profils sont sauvés en SharedPreferences
localement mais JAMAIS envoyés au backend. Multi-device est impossible.

## LE FIX

### 1. Appeler claimLocalData() après chaque update significatif de profil

File: apps/mobile/lib/providers/coach_profile_provider.dart

Ajouter une méthode privée de sync :
```dart
/// Best-effort sync to backend after profile changes.
/// Fire-and-forget: failure should NOT block local operations.
Future<void> _syncToBackend() async {
  if (_profile == null || !_isLoaded) return;
  try {
    final answers = Map<String, dynamic>.from(_lastAnswers);
    await ApiService.post('/sync/claim-local-data', {
      'data': answers,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'local_data_version': 1,
    });
  } catch (e) {
    debugPrint('[CoachProfile] Backend sync failed (non-fatal): $e');
  }
}
```

### 2. Appeler _syncToBackend() aux bons moments

Dans les méthodes suivantes, APRÈS la persistence locale ET notifyListeners() :
- `mergeAnswers()` — après `notifyListeners()`
- `updateFromSmartFlow()` — après `notifyListeners()`
- `updateFromLppExtraction()` — après `notifyListeners()`
- `updateFromRefresh()` — après `notifyListeners()`

```dart
notifyListeners();
_syncToBackend(); // Fire-and-forget, ne bloque pas l'UI
```

NE PAS appeler dans `addCheckIn()` ou `updateContributions()` (trop fréquent).

### 3. Sync au login aussi

File: apps/mobile/lib/providers/auth_provider.dart

Dans `_hydrateProfileFromBackend()`, après le merge réussi, trigger un
sync inverse (local → backend) si le profil local a des données plus récentes :
```dart
// Si local a des données et backend est vide, push local → backend
if (localProfile != null && remoteData.isEmpty) {
  context.read<CoachProfileProvider>()._syncToBackend();
}
```

## VÉRIFICATION END-TO-END
1. User remplit Quick Start (age, salary, canton)
2. Vérifier que /claim-local-data est appelé (log ou breakpoint)
3. User se connecte sur un autre appareil
4. Vérifier que /profiles/me retourne les données syncées
5. flutter test — tous passent
6. git commit: "fix(sync): wire profile sync to backend via claimLocalData()"
```

---

## PROMPT 2 — Donation + Housing Sale : créer les endpoints (P0)

```
Tu es un ingénieur backend Python/FastAPI.

## CONTEXTE
- Branche : feature/w15-wire-life-events
- Run pytest tests/ -q AVANT et APRÈS

## LE PROBLÈME
donation_service.py et housing_sale_service.py sont COMPLETS (logique,
tests, même écrans Flutter) mais n'ont AUCUN endpoint. L'utilisateur
clique "Évaluer une donation" → 404.

## LE FIX

### 1. Créer l'endpoint donation

File: services/backend/app/api/v1/endpoints/life_events.py (existant)

Ajouter au fichier existant (qui a déjà divorce et succession) :

```python
from app.services.donation_service import DonationService

@router.post("/donation/simulate", response_model=DonationResponse)
@limiter.limit("10/minute")
def simulate_donation(
    request: Request,
    body: DonationRequest,
    _user: User = Depends(require_current_user),
) -> DonationResponse:
    """Simulate tax impact of a donation (CC art. 239-252)."""
    result = DonationService.simulate(
        montant=body.montant,
        lien_parente=body.lien_parente,
        canton=body.canton,
    )
    return DonationResponse(**result)
```

Créer les schemas si nécessaires dans schemas/life_events.py :
```python
class DonationRequest(BaseModel):
    montant: float = Field(..., ge=0, le=10_000_000)
    lien_parente: str = Field(..., description="direct/indirect/tiers")
    canton: str = Field(..., min_length=2, max_length=2)

class DonationResponse(BaseModel):
    impot_donation: float
    taux_effectif: float
    reserve_hereditaire: float
    quotite_disponible: float
    disclaimer: str
    sources: list[str]
```

### 2. Créer l'endpoint housing sale

Même fichier :
```python
from app.services.housing_sale_service import HousingSaleService

@router.post("/housing-sale/simulate", response_model=HousingSaleResponse)
@limiter.limit("10/minute")
def simulate_housing_sale(
    request: Request,
    body: HousingSaleRequest,
    _user: User = Depends(require_current_user),
) -> HousingSaleResponse:
    """Simulate capital gains tax on property sale (LIFD art. 12)."""
    result = HousingSaleService.simulate(
        prix_vente=body.prix_vente,
        prix_achat=body.prix_achat,
        duree_detention=body.duree_detention,
        canton=body.canton,
        epl_utilise=body.epl_utilise,
    )
    return HousingSaleResponse(**result)
```

### 3. Vérifier que le router les inclut

File: services/backend/app/api/v1/router.py
Vérifier que life_events router est enregistré. S'il l'est déjà (pour
divorce/succession), les nouveaux endpoints seront automatiquement inclus.

## VÉRIFICATION
1. curl POST /api/v1/life-events/donation/simulate avec token → 200 + résultat
2. curl POST /api/v1/life-events/housing-sale/simulate avec token → 200 + résultat
3. pytest tests/ -q — tous passent
4. git commit: "feat(life-events): wire donation + housing sale endpoints"
```

---

## PROMPT 3 — Snapshots : câbler Flutter → Backend (P0)

```
Tu es un ingénieur Flutter + Python senior.

## CONTEXTE
- Branche : feature/w15-wire-snapshots
- Run flutter analyze + flutter test + pytest tests/ -q AVANT et APRÈS

## LE PROBLÈME
Les snapshots financiers sont stockés en mémoire uniquement
(static final List<> _snapshots = []). Le backend a l'API prête
mais Flutter ne l'appelle JAMAIS. Pas d'UI timeline.

## LE FIX

### 1. Persister les snapshots au backend

File: apps/mobile/lib/services/snapshot_service.dart

Modifier `createSnapshot()` pour envoyer au backend :
```dart
static Future<void> createSnapshot(CoachProfile profile) async {
  final snapshot = FinancialSnapshot.fromProfile(profile);
  _snapshots.add(snapshot); // Garder le cache local

  // Sync au backend (fire-and-forget)
  try {
    await ApiService.post('/snapshots', snapshot.toJson());
  } catch (e) {
    debugPrint('[Snapshot] Backend sync failed: $e');
  }
}
```

### 2. Charger les snapshots depuis le backend au startup

```dart
static Future<void> loadFromBackend() async {
  try {
    final data = await ApiService.get('/snapshots?limit=50');
    final list = (data['snapshots'] as List?)
        ?.map((s) => FinancialSnapshot.fromJson(s))
        .toList() ?? [];
    _snapshots = list;
  } catch (e) {
    debugPrint('[Snapshot] Load failed: $e');
  }
}
```

Appeler `loadFromBackend()` dans `main.dart` au startup (fire-and-forget).

### 3. Trigger automatique

Créer un snapshot automatiquement :
- Après chaque check-in mensuel (`addCheckIn()` dans coach_profile_provider)
- Après un document scan (LPP certificate)

```dart
// Dans coach_profile_provider.dart, après addCheckIn() :
SnapshotService.createSnapshot(_profile!);
```

### 4. Pas d'UI timeline pour l'instant (P2)

Ajouter un TODO :
```dart
// TODO(P2): Implement snapshot timeline screen (/financial-timeline)
// Backend supports GET /snapshots with date range
// Display: line chart of patrimoine net, replacement rate, confidence over time
```

## VÉRIFICATION
1. User fait un check-in → snapshot créé → POST /snapshots appelé
2. User redémarre l'app → snapshots chargés depuis backend
3. flutter test — tous passent
4. pytest tests/ -q — tous passent
5. git commit: "fix(snapshots): wire Flutter → backend persistence + auto-trigger"
```

---

## PROMPT 4 — Coach insights : câbler l'extraction (P1)

```
Tu es un ingénieur Flutter senior.

## CONTEXTE
- Branche : feature/w15-wire-coach-insights
- Run flutter analyze + flutter test AVANT et APRÈS

## LE PROBLÈME
CoachMemoryService.saveInsight() existe mais n'est JAMAIS appelé.
Le coach n'a aucune mémoire cross-session.

## LE FIX

### 1. Extraire des insights après chaque réponse coach

File: apps/mobile/lib/screens/coach/coach_chat_screen.dart

Après que le coach a répondu (après ComplianceGuard, après affichage),
extraire un insight simple basé sur le contenu :

```dart
/// Extract a simple insight from the coaching exchange.
Future<void> _extractAndSaveInsight(String userMessage, String coachResponse) async {
  // Only save insights for substantive exchanges (not greetings)
  if (userMessage.length < 20 || coachResponse.length < 50) return;

  // Simple topic detection from user message
  String? topic;
  if (RegExp(r'3a|pilier|troisième').hasMatch(userMessage.toLowerCase())) {
    topic = 'pilier_3a';
  } else if (RegExp(r'lpp|2e pilier|caisse|rachat').hasMatch(userMessage.toLowerCase())) {
    topic = 'lpp';
  } else if (RegExp(r'retraite|pension|rente').hasMatch(userMessage.toLowerCase())) {
    topic = 'retraite';
  } else if (RegExp(r'impôt|fiscal|déduction').hasMatch(userMessage.toLowerCase())) {
    topic = 'fiscalite';
  } else if (RegExp(r'budget|dépense|économi').hasMatch(userMessage.toLowerCase())) {
    topic = 'budget';
  }

  if (topic == null) return; // Skip non-financial exchanges

  final insight = CoachInsight(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    topic: topic,
    summary: coachResponse.length > 200
        ? '${coachResponse.substring(0, 200)}...'
        : coachResponse,
    type: 'conversation',
    createdAt: DateTime.now(),
  );

  await CoachMemoryService.saveInsight(insight);
}
```

### 2. Appeler après chaque échange

Dans la méthode qui reçoit la réponse du coach (après ComplianceGuard) :
```dart
// Après que le message coach est affiché et validé
_extractAndSaveInsight(userMessage, coachResponse);
```

## VÉRIFICATION
1. User pose une question sur le 3a → coach répond
2. Vérifier que CoachMemoryService.saveInsight() est appelé (debugPrint)
3. Nouvelle session → vérifier que l'insight apparaît dans le context injector
4. flutter test — tous passent
5. git commit: "fix(coach): wire insight extraction from coaching exchanges"
```

---

## PROMPT 5 — Audit trail : endpoint de lecture (P1)

```
Tu es un ingénieur backend Python/FastAPI.

## CONTEXTE
- Branche : feature/w15-wire-audit-read
- Run pytest tests/ -q AVANT et APRÈS

## LE PROBLÈME
audit_service.py écrit des événements (30+ locations) mais il n'y a
AUCUN endpoint pour les LIRE. Impossible d'auditer la sécurité.

## LE FIX

### 1. Créer l'endpoint admin de lecture

File: services/backend/app/api/v1/endpoints/admin.py (existant ou nouveau)

```python
from app.models.audit_event import AuditEventModel

@router.get("/audit", response_model=AuditListResponse)
@limiter.limit("5/minute")
def list_audit_events(
    request: Request,
    _user: User = Depends(require_current_user),
    db: Session = Depends(get_db),
    event_type: Optional[str] = Query(None),
    user_id: Optional[str] = Query(None),
    limit: int = Query(50, ge=1, le=500),
    offset: int = Query(0, ge=0),
):
    # Admin check
    has_role = getattr(_user, 'role', None) == 'support_admin'
    if not has_role:
        raise HTTPException(403, "Admin role required")

    query = db.query(AuditEventModel)
    if event_type:
        query = query.filter(AuditEventModel.event_type == event_type)
    if user_id:
        query = query.filter(AuditEventModel.user_id == user_id)

    total = query.count()
    events = query.order_by(
        AuditEventModel.created_at.desc()
    ).offset(offset).limit(limit).all()

    return AuditListResponse(
        events=[AuditEventSummary.from_orm(e) for e in events],
        total=total,
        limit=limit,
        offset=offset,
    )
```

### 2. Créer les schemas

```python
class AuditEventSummary(BaseModel):
    id: str
    event_type: str
    user_id: Optional[str]
    status: str
    created_at: datetime
    details_json: Optional[dict]

    class Config:
        from_attributes = True

class AuditListResponse(BaseModel):
    events: list[AuditEventSummary]
    total: int
    limit: int
    offset: int
```

### 3. Enregistrer la route

Vérifier que le router admin est inclus dans router.py.

## VÉRIFICATION
1. curl GET /api/v1/admin/audit?limit=10 avec admin token → 200 + events
2. curl GET /api/v1/admin/audit sans token → 401
3. curl GET /api/v1/admin/audit avec user normal → 403
4. pytest tests/ -q — tous passent
5. git commit: "feat(audit): add admin endpoint to read audit trail"
```

---

## PROMPT 6 — Feature flags : enforcer côté backend (P1)

```
Tu es un ingénieur backend Python senior.

## CONTEXTE
- Branche : feature/w15-wire-feature-flags
- Run pytest tests/ -q AVANT et APRÈS

## LE PROBLÈME
3 feature flags sont exposés au frontend mais JAMAIS checkés côté backend.
Le backend ignore les flags et autorise tout.

## LE FIX

### 1. Créer un helper de vérification

File: services/backend/app/services/feature_flags.py (existant)

Ajouter une méthode de gate :
```python
@staticmethod
def require_flag(flag_name: str) -> None:
    """Raise 403 if feature flag is disabled."""
    flags = FeatureFlags.get_flags()
    if not flags.get(flag_name, False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Feature '{flag_name}' is not enabled.",
        )
```

### 2. Appliquer aux endpoints concernés

File: services/backend/app/api/v1/endpoints/open_banking.py
```python
# Au début de chaque endpoint Open Banking :
FeatureFlags.require_flag("enable_blink_production")
```

File: services/backend/app/api/v1/endpoints/admin.py (si admin screens)
```python
# Au début des endpoints admin (en PLUS du role check) :
FeatureFlags.require_flag("enable_admin_screens")
```

### 3. Documenter les flags

File: services/backend/.env.example
Vérifier que tous les FF_ sont documentés avec leur effet.

## VÉRIFICATION
1. FF_ENABLE_BLINK_PRODUCTION=false → Open Banking endpoints → 403
2. FF_ENABLE_ADMIN_SCREENS=false → Admin endpoints → 403 (même avec admin role)
3. pytest tests/ -q — tous passent
4. git commit: "fix(flags): enforce feature flags on backend endpoints"
```

---

## PROMPT 7 — Cleanup infrastructure morte (P2)

```
Tu es un ingénieur senior. Nettoie le code mort.

## CONTEXTE
- Branche : feature/w15-cleanup-dead-code
- Run flutter analyze + flutter test + pytest tests/ -q AVANT et APRÈS

## FIXES

### 1. Supprimer connectors/base.py (abstract base jamais subclassé)
File: services/backend/app/services/connectors/base.py
Action: Supprimer le fichier. Aucun import n'en dépend.

### 2. Supprimer i18n/translations.py (module jamais appelé)
File: services/backend/app/services/i18n/translations.py
Action: Supprimer le fichier. Les disclaimers sont hardcodés dans chaque service.
Si le dossier i18n/ est vide après suppression, supprimer le dossier aussi.

### 3. Documenter Open Banking comme Phase 3+
File: apps/mobile/lib/services/open_banking_service.dart
Ajouter un commentaire en haut :
```dart
/// OPEN BANKING — Phase 3+ (FINMA gate)
///
/// Ce service est ENTIÈREMENT MOCKÉ. isEnabled = false.
/// Aucune donnée réelle n'est échangée.
/// Activation prévue après consultation réglementaire FINMA.
/// Ne PAS supprimer — l'architecture est prête pour l'activation.
```

### 4. Supprimer la méthode deprecated createProfile()
File: apps/mobile/lib/services/api_service.dart
La migration vers /claim-local-data est faite (Prompt 1 ci-dessus).
Vérifier que quick_start_screen.dart n'appelle plus createProfile().
Si c'est le cas, supprimer la méthode @Deprecated.

## VÉRIFICATION
1. grep "connectors/base" services/backend/ → 0 résultat
2. grep "i18n/translations" services/backend/ → 0 résultat
3. flutter analyze — 0 errors
4. pytest tests/ -q — tous passent
5. git commit: "chore(cleanup): remove dead code (connectors/base, i18n/translations)"
```

---

## PROMPT 8 — Suggested actions : améliorer (P2)

```
Tu es un ingénieur Flutter senior.

## CONTEXTE
- Branche : feature/w15-improve-suggestions
- Run flutter analyze + flutter test AVANT et APRÈS

## LE PROBLÈME
Les suggested actions sont générées par keyword matching local sur le
MESSAGE DE L'UTILISATEUR (pas la réponse du coach). Pas contextuelles.
CoachResponse.suggestedActions est hardcodé à null.

## LE FIX (pragmatique, pas architectural)

Au lieu de câbler le LLM (complexe, token cost), améliorer le keyword
matching pour qu'il analyse AUSSI la réponse du coach :

File: apps/mobile/lib/screens/coach/coach_chat_screen.dart

Modifier `_inferSuggestedActions()` :
```dart
List<SuggestedAction>? _inferSuggestedActions(
  String userMessage,
  String coachResponse, // AJOUTER ce paramètre
) {
  final combined = '$userMessage $coachResponse'.toLowerCase();

  final actions = <SuggestedAction>[];

  if (RegExp(r'3a|pilier|troisième|versement').hasMatch(combined)) {
    actions.add(SuggestedAction(
      label: S.of(context)!.simPillar3a,
      route: '/pilier-3a',
    ));
  }
  if (RegExp(r'lpp|2e pilier|rachat|caisse').hasMatch(combined)) {
    actions.add(SuggestedAction(
      label: S.of(context)!.simLppBuyback,
      route: '/lpp-deep',
    ));
  }
  if (RegExp(r'retraite|rente|capital|pension').hasMatch(combined)) {
    actions.add(SuggestedAction(
      label: S.of(context)!.simRenteVsCapital,
      route: '/rente-vs-capital',
    ));
  }
  if (RegExp(r'impôt|fiscal|déduction|déclaration').hasMatch(combined)) {
    actions.add(SuggestedAction(
      label: S.of(context)!.simTaxEstimate,
      route: '/tax-estimate',
    ));
  }
  if (RegExp(r'budget|dépense|économi|épargn').hasMatch(combined)) {
    actions.add(SuggestedAction(
      label: S.of(context)!.simBudget,
      route: '/budget',
    ));
  }
  if (RegExp(r'hypothèque|immobilier|achat|maison|appart').hasMatch(combined)) {
    actions.add(SuggestedAction(
      label: S.of(context)!.simMortgage,
      route: '/hypotheque',
    ));
  }

  return actions.isEmpty ? null : actions.take(3).toList();
}
```

Mettre à jour l'appel pour passer les deux messages :
```dart
final suggestions = _inferSuggestedActions(userMessage, coachResponse);
```

## VÉRIFICATION
1. User demande "comment optimiser mon 3a?" → coach répond → chip "Simuler mon 3a" apparaît
2. User demande "bonjour" → pas de chips (pas de keyword financier)
3. flutter test — tous passent
4. git commit: "fix(coach): suggested actions from user + coach message (not user only)"
```

---

## ORCHESTRATION

```
Tu es un orchestrateur de sprint. Ta mission : lancer les 8 prompts
du fichier docs/W15_FACADE_FIX_PROMPTS.md.

## RÈGLES
- Chaque prompt = sa propre feature branch depuis dev
- flutter analyze + flutter test + pytest tests/ -q après chaque merge
- VÉRIFIER LE CÂBLAGE end-to-end après chaque merge

## PLAN D'EXÉCUTION

### VAGUE 1 — P0 impact utilisateur (3 agents EN PARALLÈLE)
| Agent | Prompt | Branch |
|-------|--------|--------|
| A | P1 (Profile sync) | feature/w15-wire-profile-sync |
| B | P2 (Donation + Housing Sale) | feature/w15-wire-life-events |
| C | P3 (Snapshots) | feature/w15-wire-snapshots |

Pas de conflit. Merger : B → C → A

### VAGUE 2 — P1 features dégradées (3 agents EN PARALLÈLE)
| Agent | Prompt | Branch |
|-------|--------|--------|
| D | P4 (Coach insights) | feature/w15-wire-coach-insights |
| E | P5 (Audit trail read) | feature/w15-wire-audit-read |
| F | P6 (Feature flags enforce) | feature/w15-wire-feature-flags |

Pas de conflit. Merger : F → E → D

### VAGUE 3 — P2 cleanup (2 agents EN PARALLÈLE)
| Agent | Prompt | Branch |
|-------|--------|--------|
| G | P7 (Cleanup dead code) | feature/w15-cleanup-dead-code |
| H | P8 (Suggested actions) | feature/w15-improve-suggestions |

Pas de conflit. Merger : G → H

### VÉRIFICATION FINALE — CÂBLAGE END-TO-END
1. Profile sync : update salary → backend reçoit via /claim-local-data ? ✅/❌
2. Donation : POST /life-events/donation/simulate → 200 ? ✅/❌
3. Housing sale : POST /life-events/housing-sale/simulate → 200 ? ✅/❌
4. Snapshots : check-in → snapshot POST /snapshots ? ✅/❌
5. Coach insights : échange financier → saveInsight() appelé ? ✅/❌
6. Audit trail : GET /admin/audit → events retournés ? ✅/❌
7. Feature flags : FF_*=false → backend 403 ? ✅/❌
8. Suggested actions : réponse coach financière → chips contextuels ? ✅/❌

Si UN seul ❌ → sprint PAS terminé.

## CRITÈRES DE SUCCÈS
- 8/8 branches mergées
- 0 test failures
- 8/8 câblages vérifiés ✅
- 0 dead code files (connectors/base, i18n/translations supprimés)
- git branch → seulement dev, main, staging
```
