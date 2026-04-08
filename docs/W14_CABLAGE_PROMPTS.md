# W14 — Sprint de câblage (connexions manquantes)

> Ce document contient les prompts pour CONNECTER les composants
> qui fonctionnent individuellement mais ne sont PAS câblés entre eux.
>
> RÈGLE : chaque prompt trace le flux END-TO-END et vérifie chaque maillon.

---

## PROMPT 1 — Câblage Voice : cashLevel + anti-patterns → Claude (P0)

```
Tu es un ingénieur full-stack senior. Tu CÂBLES les composants voice
qui existent mais ne sont PAS connectés. Chaque fix doit être vérifié
en traçant le flux end-to-end.

## CONTEXTE
- Branche : feature/w14-wire-voice
- Run flutter analyze + flutter test + pytest tests/ -q AVANT et APRÈS

## LE PROBLÈME
L'utilisateur choisit cashLevel=5 (Brut) dans l'UI. Mais Claude reçoit
toujours le prompt par défaut. Le cashLevel n'est JAMAIS envoyé au backend
et JAMAIS injecté dans le system prompt.

Les LLM_ANTI_PATTERNS sont définis (9 règles) mais JAMAIS injectés
dans le system prompt non plus.

## FLUX À CÂBLER

```
User choisit cashLevel=5 dans UI
  → SharedPreferences (EXISTE ✅)
  → CoachChatScreen._cashLevel (EXISTE ✅)
  → ??? FIL MANQUANT ???
  → CoachChatRequest (API call au backend)
  → CoachContext (backend dataclass)
  → build_system_prompt() (backend)
  → Claude system prompt contient "Ton BRUT"
```

## FIX 1 : Ajouter cashLevel au CoachChatRequest (Flutter → Backend)

File: apps/mobile/lib/screens/coach/coach_chat_screen.dart
Quand le message est envoyé au backend (chercher l'appel API /coach/chat),
ajouter cashLevel dans le body :
```dart
final response = await ApiService.post('/coach/chat', {
  'message': userMessage,
  'profile_context': profileContext,
  'cash_level': _cashLevel,  // AJOUTER CE CHAMP
  // ... existing fields
});
```

File: services/backend/app/schemas/coach_chat.py
Ajouter le champ au schema de requête :
```python
class CoachChatRequest(CoachChatBaseModel):
    message: str = Field(...)
    cash_level: int = Field(default=3, ge=1, le=5, description="Voice intensity 1-5")
    # ... existing fields
```

## FIX 2 : Injecter cashLevel dans build_system_prompt()

File: services/backend/app/api/v1/endpoints/coach_chat.py
Quand build_system_prompt() est appelé, passer le cash_level :
```python
system_prompt = build_system_prompt(
    ctx=coach_ctx,
    language=language,
    cash_level=body.cash_level,  # AJOUTER
)
```

File: services/backend/app/services/coach/claude_coach_service.py
Modifier build_system_prompt() pour accepter et injecter l'intensité :
```python
def build_system_prompt(
    ctx: Optional[CoachContext] = None,
    language: str = "fr",
    cash_level: int = 3,  # AJOUTER
) -> str:
    prompt = _BASE_SYSTEM_PROMPT

    # AJOUTER : Injection de l'intensité
    intensity_instruction = INTENSITY_MAP.get(cash_level, INTENSITY_MAP[3])
    prompt += f"\n\n## VOIX — Intensité {cash_level}/5\n{intensity_instruction}\n"

    # AJOUTER : Injection des anti-patterns
    anti_patterns_text = "\n".join(f"- {ap}" for ap in LLM_ANTI_PATTERNS)
    prompt += f"\nANTI-PATTERNS (ne fais JAMAIS) :\n{anti_patterns_text}\n"

    # ... existing code ...
```

## FIX 3 : Mapper BL et BS aux régions

File: apps/mobile/lib/services/voice/regional_voice_service.dart
OU services/backend/app/services/coach/claude_coach_service.py

Ajouter BL et BS au mapping canton → région :
```python
_CANTON_TO_PRIMARY = {
    # ... existing mappings ...
    "BL": "ZH",  # Basel-Landschaft → Deutschschweiz
    "BS": "ZH",  # Basel-Stadt → Deutschschweiz
}
```

## VÉRIFICATION END-TO-END (obligatoire)

Après les fixes, tracer le flux complet :
1. Vérifier que cashLevel est dans le body de la requête API
2. Vérifier que le schema backend accepte cash_level
3. Vérifier que build_system_prompt reçoit cash_level
4. Vérifier que le prompt envoyé à Claude contient "Ton BRUT" quand cash_level=5
5. Vérifier que les anti-patterns sont dans le prompt
6. Vérifier que BL et BS ont un mapping régional

## VALIDATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. pytest tests/ -q — tous passent
4. grep "INTENSITY_MAP\[" services/backend/ → au moins 1 usage dans build_system_prompt
5. grep "LLM_ANTI_PATTERNS" services/backend/ → au moins 1 usage dans build_system_prompt
6. git commit: "fix(voice): wire cashLevel + anti-patterns into Claude system prompt"
```

---

## PROMPT 2 — Câblage Sécurité : auth + XXE + formula injection (P0)

```
Tu es un ingénieur sécurité senior. Tu sécurises les endpoints qui
ont été créés SANS protection.

## CONTEXTE
- Branche : feature/w14-wire-security
- Run pytest tests/ -q AVANT et APRÈS

## FIX 1 : Auth sur bank import endpoint (P0)
File: services/backend/app/api/v1/endpoints/bank_import.py
Ajouter require_current_user :
```python
from app.core.auth import require_current_user

@router.post("/import", response_model=BankImportResponse)
@limiter.limit("10/minute")
async def import_bank_statement(
    request: Request,
    file: UploadFile = File(...),
    _user: User = Depends(require_current_user),  # AJOUTER
    db: Session = Depends(get_db),
) -> BankImportResponse:
```

## FIX 2 : Auth + rate limiting sur anomaly endpoint (P0)
File: services/backend/app/api/v1/endpoints/budget.py
```python
@router.post("/anomalies", response_model=AnomalyResponse)
@limiter.limit("10/minute")  # AJOUTER
def detect_anomalies(
    request: Request,
    body: AnomalyRequest,
    _user: User = Depends(require_current_user),  # AJOUTER
):
```

## FIX 3 : XXE protection XML parser (P0)
File: services/backend/app/services/bank_import_service.py
Remplacer xml.etree.ElementTree par defusedxml :
```python
# AVANT :
import xml.etree.ElementTree as ET
# APRÈS :
try:
    from defusedxml.ElementTree import fromstring as safe_fromstring
except ImportError:
    # Fallback si defusedxml pas installé
    from xml.etree.ElementTree import fromstring as _unsafe_fromstring
    def safe_fromstring(text):
        # Minimal XXE protection
        if b'<!ENTITY' in text or b'<!DOCTYPE' in text:
            raise ValueError("XML with DTD/entities rejected for security")
        return _unsafe_fromstring(text)
```
Ajouter `defusedxml>=0.7.0` dans pyproject.toml dependencies.
Remplacer TOUS les appels `ET.fromstring()` par `safe_fromstring()`.

## FIX 4 : Formula injection sanitization (P0)
File: services/backend/app/services/bank_import_service.py
Après parsing de chaque description CSV, sanitiser :
```python
def _sanitize_csv_field(value: str) -> str:
    """Prevent formula injection in CSV fields."""
    if value and value[0] in ('=', '+', '-', '@', '\t', '\r'):
        return "'" + value  # Prefix with single quote to neutralize formula
    return value
```
Appliquer à tous les champs description AVANT de créer Transaction.

## FIX 5 : Input validation anomaly endpoint
File: services/backend/app/schemas/budget.py (ou endpoint)
```python
class AnomalyRequest(BaseModel):
    transactions: List[TransactionItem] = Field(
        ..., max_length=5000,  # AJOUTER limite
    )
    mad_threshold: float = Field(3.5, gt=0.1, lt=10)  # AJOUTER bounds
    zscore_threshold: float = Field(2.5, gt=0.1, lt=10)  # AJOUTER bounds
```

## FIX 6 : Séparer income/expense dans anomaly detection
File: services/backend/app/services/anomaly_detection_service.py
```python
# AVANT :
amounts = [abs(t["amount"]) for t in transactions]

# APRÈS :
expenses = [t for t in transactions if t["amount"] < 0]
incomes = [t for t in transactions if t["amount"] >= 0]
# Detect anomalies on expenses only
amounts = [abs(t["amount"]) for t in expenses]
```

## VALIDATION
1. pytest tests/ -q — tous passent
2. Test : curl POST /bank-import/import sans token → 401/403
3. Test : curl POST /budget/anomalies sans token → 401/403
4. Test : XML avec <!ENTITY → rejeté
5. Test : CSV avec =cmd|' dans description → sanitisé
6. git commit: "fix(security): auth + XXE + formula injection + input validation"
```

---

## PROMPT 3 — Câblage Échelle 44 : registry → calculator (P1)

```
Tu es un ingénieur Flutter senior. Tu câbles UN FIL manquant.

## CONTEXTE
- Branche : feature/w14-wire-echelle44
- Run flutter analyze + flutter test AVANT et APRÈS

## LE PROBLÈME
RegulatorySyncService.getEchelle44() existe et fonctionne.
Mais avs_calculator.dart utilise le hardcodé au lieu du synced.

## LE FIX
File: apps/mobile/lib/services/financial_core/avs_calculator.dart

Remplacer :
```dart
final table = avsEchelle44; // ou const table = avsEchelle44
```

Par :
```dart
final table = RegulatorySyncService.getEchelle44();
```

Ajouter l'import si nécessaire :
```dart
import 'package:mint_mobile/services/regulatory_sync_service.dart';
```

## VÉRIFICATION
1. flutter test test/services/financial_core/avs_calculator_test.dart — tous passent
2. flutter test test/golden/ — golden couple inchangé
3. git commit: "fix(avs): wire RegulatorySyncService.getEchelle44() into calculator"
```

---

## PROMPT 4 — Câblage Anomaly → CapEngine + bank import fixes (P2)

```
Tu es un ingénieur full-stack. Tu câbles les anomalies au CapEngine
et fixes les bugs bank import.

## CONTEXTE
- Branche : feature/w14-wire-anomaly-cap
- Run flutter analyze + flutter test + pytest tests/ -q AVANT et APRÈS

## FIX 1 : Anomaly → CapEngine signal
File: apps/mobile/lib/services/cap_memory_store.dart
Ajouter un champ :
```dart
final bool hasSpendingAnomaly;
final String? lastAnomalyInsight;
```
Avec fromJson/toJson/copyWith.

File: apps/mobile/lib/services/cap_engine.dart
Ajouter un check dans la génération de candidates :
```dart
if (memory.hasSpendingAnomaly) {
  candidates.add(CapDecision(
    id: 'spending_anomaly',
    kind: CapKind.alert,
    priorityScore: _score(impact: 0.7, urgency: 0.85, ...),
    headline: memory.lastAnomalyInsight ?? 'Dépense inhabituelle détectée',
  ));
}
```

## FIX 2 : Bank import — currency from XML (pas hardcodé CHF)
File: services/backend/app/services/bank_import_service.py
Dans _finalize_result(), utiliser la currency parsée au lieu de "CHF" :
```python
currency = parsed_currency if parsed_currency else "CHF"
```

## FIX 3 : Bank import — duplicate transaction detection
Ajouter un hash-based dedup :
```python
seen = set()
unique_transactions = []
for t in transactions:
    key = (t.date, t.description, t.amount)
    if key not in seen:
        seen.add(key)
        unique_transactions.append(t)
    else:
        warnings.append(f"Doublon ignoré : {t.description} {t.amount}")
```

## FIX 4 : Bank import — Twint/PayPal categories
Ajouter aux CATEGORY_PATTERNS :
```python
"finances": [...existing..., "twint", "paypal", "revolut"],
"shopping": [...existing..., "amazon", "aliexpress", "galaxus", "digitec"],
```

## FIX 5 : createProfile() migration → /claim-local-data
File: apps/mobile/lib/screens/onboarding/quick_start_screen.dart
Remplacer l'appel à ApiService.createProfile() (ligne ~218) par
un appel à l'endpoint sync existant :
```dart
// AVANT :
await ApiService.createProfile(
  birthYear: birthYear,
  canton: canton,
  householdType: HouseholdType.single,
  ...
);

// APRÈS :
try {
  await ApiService.post('/sync/claim-local-data', {
    'birth_year': birthYear,
    'canton': canton,
    'gross_salary_annual': grossSalary,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
} catch (_) {
  // Best-effort: profile creation non-blocking for onboarding
}
```
Puis supprimer la méthode deprecated createProfile() dans api_service.dart.

## VALIDATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. pytest tests/ -q — tous passent
4. git commit: "fix(integration): wire anomaly→CapEngine, bank import fixes, createProfile migration"
```

---

## ORCHESTRATION

```
Tu es un orchestrateur de sprint. Ta mission : lancer les 4 prompts
du fichier docs/W14_CABLAGE_PROMPTS.md.

## RÈGLES
- Chaque prompt = sa propre feature branch depuis dev
- flutter analyze + flutter test + pytest tests/ -q après chaque merge
- APRÈS chaque merge, VÉRIFIER LE CÂBLAGE en traçant le flux end-to-end

## PLAN D'EXÉCUTION

### VAGUE 1 — Sécurité + Voice (2 agents EN PARALLÈLE)
| Agent | Prompt | Branch | Fichiers |
|-------|--------|--------|----------|
| A | P1 (Voice câblage) | feature/w14-wire-voice | coach_chat_screen.dart, coach_chat.py, claude_coach_service.py, schemas/coach_chat.py |
| B | P2 (Sécurité câblage) | feature/w14-wire-security | bank_import.py (endpoint), budget.py, bank_import_service.py, anomaly_detection_service.py |

Pas de conflit de fichiers. Merger : B → A

### VAGUE 2 — Échelle 44 + Anomaly/CapEngine (2 agents EN PARALLÈLE)
| Agent | Prompt | Branch | Fichiers |
|-------|--------|--------|----------|
| C | P3 (Échelle 44) | feature/w14-wire-echelle44 | avs_calculator.dart |
| D | P4 (Anomaly + bank fixes) | feature/w14-wire-anomaly-cap | cap_engine.dart, cap_memory_store.dart, bank_import_service.py, quick_start_screen.dart, api_service.dart |

Pas de conflit. Merger : C → D

### VÉRIFICATION FINALE — CÂBLAGE END-TO-END
Après merge des 4 prompts :
1. cashLevel=5 dans settings → system prompt contient "Ton BRUT" ? ✅/❌
2. Anti-patterns dans le system prompt ? ✅/❌
3. avs_calculator utilise RegulatorySyncService.getEchelle44() ? ✅/❌
4. POST /bank-import/import sans token → 401 ? ✅/❌
5. POST /budget/anomalies sans token → 401 ? ✅/❌
6. XML avec <!ENTITY → rejeté ? ✅/❌
7. CSV avec =cmd| → sanitisé ? ✅/❌
8. Anomaly détectée → CapEngine cap_spending_anomaly visible ? ✅/❌

Si UN seul ❌ → le câblage n'est PAS terminé.

## CRITÈRES DE SUCCÈS
- 4/4 branches mergées
- 0 test failures
- 8/8 vérifications de câblage passent
- git branch → seulement dev, main, staging
```
