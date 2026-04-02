# SPRINT "GRADE A" — De C+ à A-

> Ce prompt unique couvre TOUS les fixes nécessaires pour passer de C+/B- à A-.
> Il est découpé en 4 blocs indépendants, lançables en parallèle.
> Chaque bloc cible un domaine de grade et le fait monter de 2 lettres.
>
> Estimation totale : ~5 jours de travail agent.

---

## BLOC 1 — Sécurité : de B- à A (5 jours → 1 jour agent)

```
Tu es un expert sécurité senior (CISO) pour une app fintech suisse.
Tu fixes EXACTEMENT les vulnérabilités listées. Pas de refactoring. Pas d'ajout de features.

## CONTEXTE
- Branche : `feature/grade-a-security`
- `flutter analyze` + `flutter test` + `pytest tests/ -q` AVANT et APRÈS
- CLAUDE.md et rules.md sont tes références

## FIXES (11 items — ce qui sépare B- de A)

### SEC-1: Entitlement check sur /coach/chat (P0)
File: `services/backend/app/api/v1/endpoints/coach_chat.py`
Ajouter AU DÉBUT de la fonction coach_chat() :
```python
from app.services.billing_service import recompute_entitlements
effective_tier, active_features = recompute_entitlements(db, str(_user.id))
if "coachLlm" not in active_features:
    raise HTTPException(403, "Un abonnement Premium est requis pour le coaching IA.")
```

### SEC-2: Entitlement check sur /documents/upload (P0)
File: `services/backend/app/api/v1/endpoints/documents.py`
Ajouter au début de upload_document() :
```python
effective_tier, active_features = recompute_entitlements(db, str(_user.id))
if "vault" not in active_features:
    doc_count = db.query(DocumentModel).filter(DocumentModel.user_id == str(_user.id)).count()
    if doc_count >= 2:
        raise HTTPException(403, "Limite de 2 documents atteinte. Passe à Premium.")
```

### SEC-3: Stripe webhook secret obligatoire (P0)
File: `services/backend/app/api/v1/endpoints/billing.py`
Chercher là où le webhook Stripe est traité. Si `settings.STRIPE_WEBHOOK_SECRET` est vide ou None :
```python
if not settings.STRIPE_WEBHOOK_SECRET:
    raise HTTPException(403, "Webhook secret not configured — rejecting all webhooks.")
```

### SEC-4: ReDoS dans compliance_guard (P1)
File: `apps/mobile/lib/services/coach/compliance_guard.dart`
Remplacer le pattern `sans\s+(?:\w+\s+)*risque` par :
```dart
static final _sansRisquePattern = RegExp(r'sans\s+(?:\w+\s+){0,10}risque', caseSensitive: false);
```

### SEC-5: Homoglyph bypass banned terms (P1)
File: `apps/mobile/lib/services/coach/compliance_guard.dart`
Ajouter dans _sanitizeBannedTerms() AVANT la boucle de regex :
```dart
// Normalize common homoglyphs (Greek, Cyrillic → Latin)
var normalized = text
    .replaceAll('ο', 'o').replaceAll('а', 'a').replaceAll('е', 'e')
    .replaceAll('і', 'i').replaceAll('р', 'p').replaceAll('с', 'c');
```
Puis appliquer les regex sur `normalized`, pas sur `text`.

### SEC-6: AHV pattern manquant dans PII scrubbing (P1)
Files: `apps/mobile/lib/services/coach/conversation_store.dart` ET
`services/backend/app/api/v1/endpoints/coach_chat.py`
Ajouter aux deux listes de PII patterns :
```dart
RegExp(r'\b756[.\s]?\d{4}[.\s]?\d{4}[.\s]?\d{2}\b'),
```
```python
re.compile(r"\b756[.\s]?\d{4}[.\s]?\d{4}[.\s]?\d{2}\b"),
```

### SEC-7: INTERNAL_ACCESS_ENABLED guard production (P1)
File: `services/backend/app/core/config.py`
Après la classe Settings, ajouter :
```python
if (
    os.getenv("ENVIRONMENT", "development") == "production"
    and settings.INTERNAL_ACCESS_ENABLED
    and settings.INTERNAL_ACCESS_ALLOWLIST.strip() == "*"
):
    raise RuntimeError("INTERNAL_ACCESS_ENABLED=true avec wildcard en production interdit.")
```

### SEC-8: Email verification enforced en production (P1)
File: `services/backend/app/core/config.py`
Remplacer le warning par un block :
```python
if os.getenv("ENVIRONMENT", "development") == "production":
    if not settings.AUTH_REQUIRE_EMAIL_VERIFICATION:
        raise RuntimeError(
            "AUTH_REQUIRE_EMAIL_VERIFICATION must be true in production."
        )
```

### SEC-9: Markdown injection dans réponse LLM (P1)
File: `apps/mobile/lib/services/coach/compliance_guard.dart`
Avant de retourner le texte sanitisé, échapper les balises HTML :
```dart
// Escape HTML/script tags in LLM response
sanitized = sanitized
    .replaceAll('<script', '&lt;script')
    .replaceAll('</script', '&lt;/script')
    .replaceAll('<iframe', '&lt;iframe')
    .replaceAll('javascript:', 'blocked:');
```

### SEC-10: PII mobile — migrer wizard keys critiques vers SecureStorage (P1)
File: `apps/mobile/lib/providers/coach_profile_provider.dart`
Les clés contenant des données financières sensibles (q_gross_salary, q_net_income_period_chf,
q_lpp_avoir, q_3a_capital) doivent être lues/écrites via FlutterSecureStorage au lieu de
SharedPreferences. Créer un helper :
```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureWizardStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _sensitiveKeys = {
    'q_gross_salary', 'q_net_income_period_chf',
    'q_lpp_avoir', 'q_3a_capital', 'q_partner_salary',
    'q_patrimoine_liquide', 'q_dettes_total',
  };

  static Future<void> write(String key, String value) async {
    if (_sensitiveKeys.contains(key)) {
      await _storage.write(key: key, value: value);
    }
  }

  static Future<String?> read(String key) async {
    if (_sensitiveKeys.contains(key)) {
      return await _storage.read(key: key);
    }
    return null;
  }

  static Future<void> deleteAll() async {
    for (final key in _sensitiveKeys) {
      await _storage.delete(key: key);
    }
  }
}
```
Puis dans _persistFullProfile() et loadFromWizard(), utiliser SecureWizardStore
pour les clés sensibles au lieu de SharedPreferences.

### SEC-11: Terme banni "certain" (P0 compliance)
File: `apps/mobile/lib/services/financial_explanations.dart` (ligne ~305)
Chercher le mot "certain" utilisé comme absolu et reformuler en conditionnel :
```dart
// AVANT: "un certain rendement"
// APRÈS: "un rendement estimé" ou "un rendement possible"
```
Chercher aussi "garantiert" dans `app_de.arb` et "optimal" dans `independants_service.dart`.
Remplacer par des formulations conditionnelles.

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — tous passent
3. `pytest tests/ -q` — tous passent
4. Grep "garanti|certain|optimal" dans les fichiers user-facing → 0 résultat absolu
5. git commit: "fix(security): grade-A — entitlements, ReDoS, PII, compliance terms"
```

---

## BLOC 2 — Backend : de B- à A- (4 jours → 1 jour agent)

```
Tu es un architecte backend senior Python/FastAPI.
Tu fixes EXACTEMENT les problèmes listés. Pas de refactoring au-delà du scope.

## CONTEXTE
- Branche : `feature/grade-a-backend`
- `pytest tests/ -q` AVANT et APRÈS

## FIXES (9 items)

### BE-1: Privacy export pagination (P0)
File: `services/backend/app/api/v1/endpoints/privacy.py`
Ajouter LIMIT à TOUTES les queries .all() :
```python
MAX_EXPORT = 10000
events = db.query(AnalyticsEvent).filter(...).order_by(
    AnalyticsEvent.timestamp.desc()
).limit(MAX_EXPORT).all()
profiles = db.query(ProfileModel).filter(...).limit(1000).all()
docs = db.query(DocumentModel).filter(...).limit(1000).all()
snapshots = db.query(SnapshotModel).filter(...).limit(1000).all()
```

### BE-2: Account deletion transaction safety (P0)
File: `services/backend/app/api/v1/endpoints/auth.py`
Wrapper le bloc de 16+ DELETE dans un try/except avec rollback :
```python
try:
    # ... toutes les opérations DELETE existantes ...
    db.commit()
except Exception as e:
    db.rollback()
    logger.error("Account deletion failed for %s: %s", user_id, e)
    raise HTTPException(500, "Deletion failed. Contact support.")
```

### BE-3: Analytics GROUP BY limit (P0)
File: `services/backend/app/api/v1/endpoints/analytics.py`
Ajouter `.limit(100)` aux deux queries GROUP BY (lines ~143 et ~161).

### BE-4: Missing indexes (P1)
File: `services/backend/app/models/audit_event.py`
```python
created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)
```
File: `services/backend/app/models/analytics_event.py`
Ajouter :
```python
__table_args__ = (
    Index("ix_analytics_user_timestamp", "user_id", "timestamp"),
)
```

### BE-5: ScenarioModel FK wrong table (P1)
File: `services/backend/app/models/scenario.py`
Changer :
```python
profile_id = Column(String, ForeignKey("profiles.id", ondelete="CASCADE"), nullable=False, index=True)
```
Si nécessaire, créer une migration Alembic.

### BE-6: Household dissolution N+1 (P1)
File: `services/backend/app/services/household_service.py`
Collecter les user_ids AVANT de recomputer :
```python
user_ids_to_recompute = []
for member in non_owner_members:
    if member.status in ("active", "pending"):
        member.status = "revoked"
        user_ids_to_recompute.append(member.user_id)
db.flush()
for uid in user_ids_to_recompute:
    recompute_entitlements(db, uid)
```

### BE-7: Context window — per-request token budget (P1)
File: `services/backend/app/api/v1/endpoints/coach_chat.py`
Ajouter au début de la fonction :
```python
MAX_REQUEST_TOKENS = 4000
```
Dans le agent loop, après chaque LLM call :
```python
request_tokens_used += result.get("tokens_used", 0)
if request_tokens_used >= MAX_REQUEST_TOKENS:
    logger.warning("Per-request token budget exceeded: %d", request_tokens_used)
    break
```

### BE-8: Tool results truncation (P1)
File: `services/backend/app/api/v1/endpoints/coach_chat.py`
Dans le agent loop, tronquer chaque tool result :
```python
if len(result_text) > 500:
    result_text = result_text[:497] + "..."
```

### BE-9: Feature flags — sync 4 missing flags (P1)
File: `services/backend/app/api/v1/endpoints/config.py`
Ajouter au response dict :
```python
"enableOpenBanking": os.getenv("FF_ENABLE_BLINK_PRODUCTION", "false").lower() in ("1", "true"),
"enablePensionFundConnect": os.getenv("FF_ENABLE_CAISSE_PENSION_API", "false").lower() in ("1", "true"),
"enableExpertTier": os.getenv("FF_ENABLE_EXPERT_TIER", "false").lower() in ("1", "true"),
"enableAdminScreens": os.getenv("FF_ENABLE_ADMIN_SCREENS", "false").lower() in ("1", "true"),
```

### VALIDATION
1. `pytest tests/ -q` — tous passent
2. git commit: "fix(backend): grade-A — pagination, indexes, FK, token budget, feature flags"
```

---

## BLOC 3 — Flutter : de C+ à B+ (3 jours → 1 jour agent)

```
Tu es un architecte Flutter senior.
Tu fixes EXACTEMENT les problèmes listés. Pas de refactoring au-delà du scope.

## CONTEXTE
- Branche : `feature/grade-a-flutter`
- `flutter analyze` + `flutter test` + `flutter gen-l10n` AVANT et APRÈS

## FIXES (10 items)

### FL-1: Monte Carlo vers Isolate (P1)
File: `apps/mobile/lib/services/financial_core/monte_carlo_service.dart`
Wrapper la boucle de 1000 simulations dans un Isolate :
```dart
static Future<MonteCarloResult> runSimulation({...}) async {
  return await Isolate.run(() {
    // ... existing simulation code ...
  });
}
```

### FL-2: Empty catch blocks — ajouter logging (P1)
Rechercher TOUS les `catch (_) {}` et `catch (e) {}` avec body vide dans lib/.
Pour chaque occurrence, ajouter au minimum :
```dart
catch (e) {
  debugPrint('[${runtimeType}] Error: $e');
}
```
Ne PAS modifier les catch qui ont déjà du contenu (debugPrint, Sentry, etc.).

### FL-3: Hardcoded strings FR dans wizard/data files (P1)
Rechercher dans `apps/mobile/lib/` les fichiers contenant des strings françaises
hardcodées (pas dans l10n/). Pour chaque string user-facing trouvée :
1. Créer la clé dans les 6 ARB files
2. Remplacer par `S.of(context)!.newKey`
3. `flutter gen-l10n`

Focus sur les 20 strings les plus visibles (titres, messages d'erreur, labels).
NE PAS toucher aux strings dans les commentaires, les logs, ou les constantes techniques.

### FL-4: Admin buttons masqués quand flag false (P2)
File: `apps/mobile/lib/screens/profile_screen.dart`
Wrapper les boutons admin avec :
```dart
if (FeatureFlags.enableAdminScreens) ...[
  // boutons admin existants
],
```

### FL-5: Context injector — cap cross-session insights (P1)
File: `apps/mobile/lib/services/coach/context_injector_service.dart`
Trouver où les insights cross-session sont injectés et ajouter un cap :
```dart
final cappedInsights = insights.take(10).toList();
```

### FL-6: Error messages — remplacer raw Exception par ApiException (P1)
File: `apps/mobile/lib/services/api_service.dart`
Remplacer les 5 instances de `throw Exception('POST/PUT/DELETE...')` par :
```dart
throw ApiException(
  _extractErrorDetail(response.body, fallback: 'Request failed'),
  statusCode: response.statusCode,
);
```

### FL-7: Household service — localiser les erreurs (P1)
File: `apps/mobile/lib/services/household_service.dart`
Remplacer les 4 `throw Exception('Erreur ...')` par des ApiException :
```dart
final detail = jsonDecode(response.body)['detail'] ?? 'Operation failed';
throw ApiException(detail, statusCode: response.statusCode);
```

### FL-8: SLM download — localiser les erreurs (P1)
File: `apps/mobile/lib/services/slm/slm_download_service.dart`
Remplacer les 4 strings françaises hardcodées par des clés i18n.
Ajouter les clés dans les 6 ARB files.

### FL-9: Document scan — masquer les détails techniques (P1)
File: `apps/mobile/lib/screens/document_scan/document_scan_screen.dart`
Remplacer `docScanBackendParsingError(e.toString())` par un message générique
sans l'exception :
```dart
_showErrorSnack(S.of(context)!.docScanGenericError);
```

### FL-10: Coach compliance error — ajouter guidance (P1)
File: `apps/mobile/lib/screens/coach/coach_chat_screen.dart`
Quand un message est filtré par ComplianceGuard, ajouter un hint :
```dart
// Au lieu de juste "Je n'ai pas pu formuler une réponse conforme"
// Ajouter : "Essaie de reformuler ta question, ou explore les simulateurs."
```
Vérifier que la clé `coachComplianceError` dans les ARB inclut cette guidance.

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — tous passent
3. `flutter gen-l10n` — 0 errors
4. Grep `throw Exception\(` dans lib/services/ → 0 résultat (tous convertis en ApiException)
5. git commit: "fix(flutter): grade-A — Isolate, error handling, i18n, admin gates"
```

---

## BLOC 4 — UX & Compliance : de B+ à A- (2 jours → 1 jour agent)

```
Tu es un expert UX + compliance suisse (nLPD, LSFin).
Tu fixes EXACTEMENT les problèmes listés. Pas de refactoring au-delà du scope.

## CONTEXTE
- Branche : `feature/grade-a-ux-compliance`
- `flutter analyze` + `flutter test` + `flutter gen-l10n` AVANT et APRÈS

## FIXES (8 items)

### UX-1: Vous/votre → tu/ton dans coaching ARB (P1)
File: `apps/mobile/lib/l10n/app_fr.arb`
Chercher les ~11 instances de "vous " et "votre " dans du texte coaching (PAS dans
les disclaimers légaux). Remplacer par la forme "tu/ton/ta" :
- "vous avez" → "tu as"
- "votre patrimoine" → "ton patrimoine"
- "vous économisez" → "tu économises"
NE PAS toucher aux textes légaux formels (CGU, disclaimer, lettres expert).

### UX-2: Privacy Policy — sous-traitants + cross-border (P0 nLPD)
File: `legal/PRIVACY.md`
a) Vérifier que la section sous-traitants liste : Sentry, Railway, Anthropic/OpenAI,
   Apple/Google (speech), Google Fonts. Si des entrées manquent, les ajouter.
b) Vérifier que le cross-border mentionne : Railway US, SCC, hébergement Suisse prévu P2.
c) Ajouter Google Fonts si absent :
```markdown
**Google Fonts** (Google LLC, États-Unis)
- Données : adresse IP (téléchargement initial des polices)
- Durée : ponctuel (cache local)
- Base légale : intérêt légitime (affichage typographique)
```

### UX-3: Consent timing — vérifier qu'il est AVANT la collecte (P0 nLPD)
File: `apps/mobile/lib/screens/onboarding/smart_onboarding_screen.dart`
Vérifier que la consent sheet est montrée dans initState() via addPostFrameCallback(),
AVANT que l'utilisateur puisse remplir le step 1.
Si c'est déjà le cas (fixé en W11), marquer DONE.
Si pas encore fait :
```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_onboardingConsent != true) {
      _showOnboardingConsentSheet();
    }
  });
}
```

### UX-4: Termes bannis dans ARB files (P0 compliance)
Rechercher dans les 6 ARB files les termes suivants utilisés comme ABSOLUS :
- "garanti" / "garantiert" / "guaranteed"
- "certain" (au sens "sûr", pas "certains/quelques")
- "optimal" / "meilleur" / "parfait" (comme absolu)
- "sans risque" / "risikolos" / "risk-free"
Pour chaque occurrence, reformuler en conditionnel :
- "garanti" → "prévu" ou "estimé"
- "optimal" → "adapté" ou "pertinent"
- "certain" → "possible" ou "envisageable"
- "sans risque" → "à risque réduit"

### UX-5: AVS interpolation — documenter la limitation (P1)
File: `apps/mobile/lib/services/financial_core/avs_calculator.dart`
L'interpolation linéaire (vs échelle 44 concave) a un delta de 3-8% pour les revenus
moyens. Ajouter un commentaire de documentation :
```dart
/// NOTE: Uses linear interpolation between RAMD min and max.
/// The official AVS scale (Échelle 44) uses a concave curve that benefits
/// middle-income earners by 3-8%. This is a known simplification.
/// TODO(P1-Finance): Implement full Échelle 44 lookup table for production.
```

### UX-6: dateOfBirth regex anchor (P2)
File: `services/backend/app/schemas/profile.py`
Changer le pattern de `r"^\d{4}-\d{2}-\d{2}"` à `r"^\d{4}-\d{2}-\d{2}$"`.

### UX-7: Swiss phone pattern stricte (P2)
Files: `conversation_store.dart` ET `coach_chat.py`
Remplacer le pattern phone loose par :
```dart
RegExp(r'(?:\+41|0)[\s.-]?(?:76|77|78|79|[1-4]\d)[\s.-]?\d{3}[\s.-]?\d{2}[\s.-]?\d{2}')
```

### UX-8: CLAUDE.md — note replacement rate (P2)
File: `CLAUDE.md`
Après la ligne du taux de remplacement dans §8, ajouter :
```markdown
> Note : le taux de 65.5% utilise le revenu net combiné du couple et la projection
> LPP certificat CPE Plan Maxi. La formule légale standard produit un taux différent.
```

### VALIDATION
1. `flutter analyze` — 0 errors
2. `flutter test` — tous passent
3. `flutter gen-l10n` — 0 errors
4. Grep "garanti|garantiert|guaranteed|sans risque|risikolos" dans ARB → 0 absolu
5. Relire PRIVACY.md — cohérent et complet
6. git commit: "fix(ux-compliance): grade-A — vous→tu, nLPD, banned terms, AVS note"
```

---

## CHECKLIST DE LANCEMENT

| Bloc | Branch | Fichiers principaux | Parallèle avec |
|------|--------|---------------------|-----------------|
| 1 Security | `feature/grade-a-security` | coach_chat.py, documents.py, compliance_guard.dart, billing.py, config.py, coach_profile_provider.dart | 2, 3, 4 (attention: coach_chat.py partagé avec bloc 2) |
| 2 Backend | `feature/grade-a-backend` | privacy.py, auth.py, analytics.py, models/*.py, config.py, household_service.py | 3, 4 (attention: config.py partagé avec bloc 1) |
| 3 Flutter | `feature/grade-a-flutter` | monte_carlo_service.dart, api_service.dart, household_service.dart, profile_screen.dart, ARB files | 4 |
| 4 UX/Compliance | `feature/grade-a-ux-compliance` | app_fr.arb, PRIVACY.md, CLAUDE.md, avs_calculator.dart, profile.py | 3 (attention: ARB partagés) |

### ORDRE DE MERGE RECOMMANDÉ
1. Bloc 4 (UX/Compliance) — docs + ARB, peu de code
2. Bloc 1 (Security) — fixes critiques
3. Bloc 2 (Backend) — perf + indexes
4. Bloc 3 (Flutter) — error handling + i18n

### CONFLITS POTENTIELS
- `coach_chat.py` : Blocs 1 (entitlement) + 2 (token budget) → sections différentes, merge safe
- `config.py` : Blocs 1 (INTERNAL_ACCESS) + 2 (feature flags) → sections différentes
- ARB files : Blocs 3 (SLM errors) + 4 (vous→tu, banned terms) → clés différentes, merge safe
- `PRIVACY.md` : Bloc 4 seul

### GRILLE DE SCORING ATTENDUE APRÈS FIXES

| Domaine | Avant | Après | Gain |
|---------|-------|-------|------|
| Security | B- | **A** | Entitlements, ReDoS, PII chiffré, compliance terms |
| Backend | B- | **A-** | Pagination, indexes, token budget, FK correct |
| Flutter | C+ | **B+** | Isolate, error handling, i18n, admin gates |
| UX/Compliance | B+ | **A-** | nLPD, vous→tu, banned terms, AVS note |
| Financial Engine | A- | **A-** | Inchangé (déjà excellent) |
| **GLOBAL** | **C+/B-** | **A-** | **+2 lettres** |

### CE QUI RESTE POUR A (pas A-) — Phase 2
- Échelle 44 AVS complète (remplacer interpolation linéaire)
- AVS divorce splitting + bonifications éducatives
- Password complexity requirements
- Screenshot protection sur écrans financiers
- Biometric lock / app lock
- Selector/RepaintBoundary sur CoachChat + RenteVsCapital
- Refactoring coach_chat_screen.dart (4193 → <500 lignes)
- 50 vrais utilisateurs suisses testés
