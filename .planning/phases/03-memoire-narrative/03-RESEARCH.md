# Phase 3: Memoire Narrative - Research

**Researched:** 2026-04-06
**Domain:** Local encrypted biography storage, anonymized coach integration, privacy controls, data freshness decay
**Confidence:** HIGH

## Summary

Phase 3 builds a **FinancialBiography** -- a local-only, encrypted fact store that records the user's financial story over time and feeds an anonymized summary into the coach AI system prompt. The codebase already has substantial memory infrastructure: `CoachMemoryService` (SharedPreferences, 50 insights, FIFO), `MemoryContextBuilder` (1500-char context blocks), `ConversationMemoryService` (topic summaries), and `ContextInjectorService` (memory block injection into coach prompt). The existing `confidence_scorer.dart` already implements freshness decay (`_freshnessScore()` with 6-month linear decay to 0.5 at 24 months). CoachProfile already has `dataTimestamps` per field.

The primary NEW work is: (1) a structured `BiographyFact` data model in an encrypted SQLite database (sqflite_sqlcipher), (2) an `AnonymizedBiographySummary` service that rounds/redacts facts for coach prompt injection (max 2K tokens), (3) a privacy control screen ("Ce que MINT sait de toi") with view/edit/delete per fact, (4) freshness decay logic with two tiers (annual 12-month, volatile 3-month), and (5) coach prompt modifications for natural biography referencing with dating and conditional language. The backend needs minimal changes -- biography data never leaves the device; only the anonymized summary enters the system prompt client-side before the API call.

**Primary recommendation:** Build the biography layer as a new `services/biography/` module in Flutter with sqflite_sqlcipher for encrypted storage. Integrate into the existing `ContextInjectorService` pipeline. The privacy screen goes under `screens/profile/privacy_control_screen.dart` following the existing `data_transparency_screen.dart` pattern. Do NOT replace the existing CoachMemoryService/CoachInsight system -- biography is an additional, richer data layer that coexists.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Storage engine: sqflite (local SQLite) + flutter_secure_storage for AES-256 encryption key -- per BIO-02
- Data model: graph-like `BiographyFact` with fields: fact_type, value, source (document/userInput/coach), date, causal_links, temporal_links -- per BIO-01
- Encryption: AES-256 via flutter_secure_storage key + sqflite encryption extension -- per BIO-02
- What gets recorded: document extractions (from Phase 2), life event declarations, user decisions (confirm/edit/delete), coach interactions that reveal preferences
- Anonymization: `AnonymizedBiographySummary` service rounds salary to nearest 5k, removes names/employer/IBAN/identifiable dates, max 2K tokens -- per BIO-03, COMP-03
- Coach referencing: natural narrative ("Ton salaire a augmente a un peu moins de 100k") with conditional language + source dating -- per BIO-04, BIO-07
- Caisse data guardrails: always date the source, use conditional language, never present extracted data as current fact -- per BIO-07
- Refresh prompting (BIO-08): when data freshness-adjusted weight drops below 0.60, coach proactively suggests document refresh in next interaction
- Privacy control screen: new screen "Ce que MINT sait de toi" -- list of facts with source, date, edit/delete buttons -- per BIO-05
- Fact editing: inline edit -- tap fact -> edit value -> save with source="userEdit" -- per BIO-05
- Freshness decay model: annual fields 12-month decay, volatile fields 3-month decay -- flagged in UI + excluded from projections -- per BIO-06
- Stale data display: yellow warning badge on stale facts + "Donnees datant de {X} mois" label -- per COMP-02
- Every reference to user data in projections/coach responses is dated or conditioned -- per COMP-02

### Claude's Discretion
- BiographyFact schema details (exact field names, types, indexes)
- Anonymization rounding rules for non-salary fields
- Coach prompt template for biography-aware responses
- Privacy screen layout and navigation placement
- Decay model weight calculation formula

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| BIO-01 | FinancialBiography stores facts, decisions, events with causal/temporal links -- local-only | sqflite_sqlcipher 3.4.0 for encrypted local SQLite; BiographyFact model with causal_links/temporal_links as JSON columns |
| BIO-02 | Biography encrypted at rest (AES-256 via flutter_secure_storage + sqflite) | sqflite_sqlcipher uses SQLCipher 4.10 (AES-256-CBC); key stored in flutter_secure_storage (Keychain/KeyStore) |
| BIO-03 | Coach receives AnonymizedBiographySummary only (max 2K tokens) | New AnonymizedBiographySummary service; rounds salary to 5k, age-ranges dates, strips PII; token counting via simple char/4 estimate |
| BIO-04 | Coach references biography naturally -- never cites upload dates, filenames, exact amounts | Coach system prompt biography section with rules; ComplianceGuard extended with biography-specific checks |
| BIO-05 | Privacy control screen with view/edit/delete per fact | New `privacy_control_screen.dart` under `screens/profile/`; follows `data_transparency_screen.dart` pattern; GoRouter route `/profile/privacy-control` |
| BIO-06 | Data freshness decay model: annual 12mo, volatile 3mo | Extends existing `_freshnessScore()` in confidence_scorer.dart; new `FreshnessDecayService` with field-type-aware decay |
| BIO-07 | Coach guardrails for caisse data: dates source, conditional language | System prompt biography section enforces dating; ComplianceGuard validates dated references |
| BIO-08 | Coach proactively prompts for document refresh when freshness < 0.60 | `BiographyRefreshDetector` checks freshness weights on context build; injects refresh nudge into coach context |
| COMP-02 | No stale data as truth: every reference dated or conditioned | System prompt rules + ComplianceGuard check for unconditioned stale references |
| COMP-03 | FinancialBiography data never leaves device -- AnonymizedBiographySummary only in LLM prompts | Architecture enforces: BiographyRepository is local-only; only AnonymizedBiographySummary enters system prompt |
</phase_requirements>

## Project Constraints (from CLAUDE.md)

- **Storage**: flutter_secure_storage ^9.0.0 already in pubspec.yaml; sqflite NOT yet added [VERIFIED: pubspec.yaml grep]
- **State management**: Provider pattern (no raw StatefulWidget for shared data)
- **Navigation**: GoRouter -- no Navigator.push
- **i18n**: ALL user-facing strings in 6 ARB files via AppLocalizations
- **Colors**: MintColors.* only -- no hardcoded hex
- **Testing**: minimum 10 unit tests per service, golden couple validation
- **Compliance**: ComplianceGuard validates ALL LLM output; no PII in system prompt; CoachContext NEVER contains exact salary/savings/debts/NPA/employer
- **No hand-roll crypto**: use established libraries for encryption (sqflite_sqlcipher)
- **Backend = source of truth for constants**: but biography is local-only (exception by design)

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| sqflite_sqlcipher | 3.4.0 | Encrypted SQLite database | Drop-in sqflite replacement with SQLCipher AES-256; same API, just adds password parameter [VERIFIED: pub.dev] |
| flutter_secure_storage | ^9.0.0 (in pubspec) | Encryption key storage | Already in project; stores AES key in platform Keychain/KeyStore [VERIFIED: pubspec.yaml] |
| path_provider | (check pubspec) | Database file path | Standard Flutter path resolution for app documents directory [ASSUMED] |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| uuid | (already in project) | BiographyFact IDs | Already imported in coach_profile_provider.dart [VERIFIED: codebase] |
| provider | (already in project) | BiographyProvider state | Project-wide state management pattern [VERIFIED: codebase] |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| sqflite_sqlcipher | sqflite + manual AES on JSON | sqflite_sqlcipher is cleaner -- encryption at DB level, not field level; no manual encrypt/decrypt per read/write |
| sqflite_sqlcipher | Hive + encryption | Hive is key-value, not relational; graph-like links and queries are harder; sqflite SQL is better for causal/temporal link queries |
| sqflite_sqlcipher | drift (moor) | drift adds code generation complexity; sqflite_sqlcipher is simpler for a single-table fact store |

**Installation:**
```bash
cd apps/mobile && flutter pub add sqflite_sqlcipher path_provider
```

**Note:** sqflite_sqlcipher replaces sqflite import -- uses `import 'package:sqflite_sqlcipher/sqflite.dart'` with same API + `password` parameter on `openDatabase`. [VERIFIED: pub.dev documentation]

## Architecture Patterns

### Recommended Project Structure
```
apps/mobile/lib/
  services/
    biography/
      biography_repository.dart       # CRUD for BiographyFact (sqflite_sqlcipher)
      biography_fact.dart             # BiographyFact data model
      anonymized_biography_service.dart  # Rounds/redacts for coach prompt
      freshness_decay_service.dart    # Field-type-aware decay calculation
      biography_refresh_detector.dart # Detects stale data, generates refresh nudges
  providers/
    biography_provider.dart           # ChangeNotifier wrapping BiographyRepository
  screens/
    profile/
      privacy_control_screen.dart     # "Ce que MINT sait de toi" (BIO-05)
  widgets/
    biography/
      fact_card.dart                  # Reusable fact display card
      fact_edit_sheet.dart            # Bottom sheet for inline editing
```

### Pattern 1: Encrypted Database Initialization
**What:** Open encrypted SQLite on app startup with key from secure storage
**When to use:** Every app launch, before any biography read/write
**Example:**
```dart
// Source: sqflite_sqlcipher pub.dev documentation
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class BiographyRepository {
  static const _dbName = 'mint_biography.db';
  static const _keyAlias = 'mint_biography_key';
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);

    // Get or generate encryption key
    const storage = FlutterSecureStorage();
    String? key = await storage.read(key: _keyAlias);
    if (key == null) {
      // Generate 32-byte hex key on first launch
      key = List.generate(32, (_) => Random.secure().nextInt(256))
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      await storage.write(key: _keyAlias, value: key);
    }

    return openDatabase(
      path,
      password: key,
      version: 1,
      onCreate: _createTables,
    );
  }

  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE biography_facts (
        id TEXT PRIMARY KEY,
        fact_type TEXT NOT NULL,
        field_path TEXT,
        value TEXT NOT NULL,
        source TEXT NOT NULL,
        source_date TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        causal_links TEXT DEFAULT '[]',
        temporal_links TEXT DEFAULT '[]',
        is_deleted INTEGER DEFAULT 0,
        freshness_category TEXT DEFAULT 'annual'
      )
    ''');
    await db.execute('CREATE INDEX idx_fact_type ON biography_facts(fact_type)');
    await db.execute('CREATE INDEX idx_field_path ON biography_facts(field_path)');
    await db.execute('CREATE INDEX idx_source ON biography_facts(source)');
  }
}
```
[ASSUMED: code pattern based on sqflite_sqlcipher API docs]

### Pattern 2: Anonymized Biography Summary
**What:** Transform raw biography into a privacy-safe, token-limited summary for coach prompt
**When to use:** Every coach chat session, during context injection
**Example:**
```dart
class AnonymizedBiographySummary {
  static const _maxTokens = 2000; // ~8000 chars at 4 chars/token
  static const _maxChars = 8000;

  /// Build anonymized summary from all active (non-stale, non-deleted) facts.
  static String build(List<BiographyFact> facts, {DateTime? now}) {
    final currentDate = now ?? DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln('--- BIOGRAPHIE FINANCIERE ---');
    buffer.writeln('Rappel: JAMAIS de montant exact, nom, employeur, IBAN.');
    buffer.writeln('Utilise des approximations ("un peu moins de 100k").');
    buffer.writeln('Date TOUJOURS la source ("selon certificat de mars 2025").');
    buffer.writeln();

    for (final fact in facts) {
      if (fact.isDeleted) continue;
      final freshness = FreshnessDecayService.weight(fact, currentDate);
      if (freshness < 0.30) continue; // Skip very stale data

      final anonymized = _anonymize(fact);
      final dateLabel = _formatSourceDate(fact.sourceDate);
      final freshnessLabel = freshness < 0.60 ? ' [DONNEE ANCIENNE]' : '';
      buffer.writeln('- $anonymized ($dateLabel)$freshnessLabel');

      if (buffer.length > _maxChars) break; // Hard limit
    }

    buffer.writeln('--- FIN BIOGRAPHIE ---');
    return buffer.toString();
  }

  static String _anonymize(BiographyFact fact) {
    // Round salary to nearest 5k
    if (fact.factType == 'salary') {
      final amount = double.tryParse(fact.value) ?? 0;
      final rounded = (amount / 5000).round() * 5000;
      return 'Salaire: ~${rounded ~/ 1000}k CHF';
    }
    // Round LPP capital to nearest 10k
    if (fact.factType == 'lpp_capital') {
      final amount = double.tryParse(fact.value) ?? 0;
      final rounded = (amount / 10000).round() * 10000;
      return 'Avoir LPP: ~${rounded ~/ 1000}k CHF';
    }
    // Other fields: return as-is if non-sensitive
    return '${fact.factType}: ${fact.value}';
  }
}
```
[ASSUMED: code pattern based on existing MemoryContextBuilder and privacy rules from CLAUDE.md]

### Pattern 3: Context Injector Integration
**What:** Add biography block to existing `ContextInjectorService` memory injection pipeline
**When to use:** Extend existing service, do NOT create parallel injection
**Example:**
```dart
// In context_injector_service.dart -- ADD to existing buildEnrichedContext()
// After conversation memory block, before closing --- FIN MEMOIRE ---:
final biographySummary = await AnonymizedBiographySummary.build(
  await BiographyRepository.getActiveFacts(),
);
if (biographySummary.isNotEmpty) {
  memoryBlock.writeln(biographySummary);
}
```
[ASSUMED: integration point based on existing ContextInjectorService structure]

### Anti-Patterns to Avoid
- **Sending raw BiographyFact to backend**: NEVER. Only AnonymizedBiographySummary enters LLM prompts. This is a compliance requirement (COMP-03).
- **Replacing CoachMemoryService**: Biography coexists with existing memory. CoachInsight captures conversation-level insights; BiographyFact captures structured financial data. They serve different purposes.
- **Manual AES encryption on fields**: Use sqflite_sqlcipher's database-level encryption. Do not implement field-level encryption manually.
- **Querying biography in build()**: Heavy queries in widget build methods. Use BiographyProvider.facts getter with cached data.
- **Storing encryption key in SharedPreferences**: Key MUST be in flutter_secure_storage (Keychain/KeyStore). SharedPreferences is plaintext.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Database encryption | Custom AES wrapper around sqflite | sqflite_sqlcipher | SQLCipher is battle-tested (used by Signal); handles key derivation, page encryption, HMAC verification |
| Encryption key storage | File-based key storage | flutter_secure_storage | Platform Keychain (iOS) / KeyStore (Android) is hardware-backed |
| Token counting | Custom tokenizer | chars / 4 estimate | For a 2K token budget, char estimate is sufficient; BPE tokenizer adds unnecessary complexity |
| Freshness decay curve | New decay algorithm | Extend existing `_freshnessScore()` in confidence_scorer.dart | Already implements linear decay with floor; just needs two-tier threshold |
| PII detection in anonymizer | Regex-based PII scrub | Field-type-aware rounding | We know exactly which fields contain sensitive data (salary, IBAN, etc.); type-based anonymization is more reliable than regex |

**Key insight:** The codebase already has 80% of the memory infrastructure. The new biography layer slots into existing patterns (ContextInjectorService, ComplianceGuard, Provider). The only truly new component is the encrypted SQLite store.

## Common Pitfalls

### Pitfall 1: Key Loss on App Reinstall
**What goes wrong:** User reinstalls app, flutter_secure_storage key is gone, encrypted database is unreadable.
**Why it happens:** iOS Keychain persists across reinstalls by default, but Android KeyStore does NOT.
**How to avoid:** On Android, detect missing key + existing database file = show "data reset" dialog. Accept this as expected behavior for local-only encrypted data (no cloud backup by design). Document this in the privacy screen ("Vos donnees sont protegees par chiffrement local").
**Warning signs:** Database open throws `DatabaseException` with cipher error.

### Pitfall 2: Anonymization Leaks in Edge Cases
**What goes wrong:** AnonymizedBiographySummary accidentally includes exact amounts or identifiable patterns (e.g., "salaire de 122'207 CHF" instead of "~120k CHF").
**Why it happens:** New fact types added without anonymization rules; string interpolation bypasses rounding.
**How to avoid:** Whitelist-based anonymization -- every fact type MUST have an explicit anonymization rule. Unknown types get generic "[donnee confidentielle]" label. Unit test every fact type.
**Warning signs:** ComplianceGuard catches exact salary in coach output (defense-in-depth).

### Pitfall 3: Stale Data in Projections
**What goes wrong:** Projection uses 18-month-old salary data without flagging uncertainty.
**Why it happens:** BiographyFact feeds CoachProfile without checking freshness first.
**How to avoid:** BiographyProvider.getFactsForProjection() filters by freshness weight >= 0.60. Stale facts are available for display (privacy screen) but excluded from projection inputs. Confidence scorer already penalizes stale data.
**Warning signs:** Projection confidence score drops when data ages.

### Pitfall 4: Coach Over-References Biography
**What goes wrong:** Coach mentions biography facts in every response, feels creepy/surveillance-like.
**Why it happens:** System prompt biography section is too prominent; LLM over-indexes on injected context.
**How to avoid:** Biography section positioned AFTER main instructions in system prompt. Explicit rule: "Reference biography ONLY when contextually relevant to the user's current question. Maximum 1 biography reference per response."
**Warning signs:** User feedback indicating discomfort; coach responses feel formulaic.

### Pitfall 5: Database Migration Pain
**What goes wrong:** BiographyFact schema changes in future sprints break existing databases.
**Why it happens:** SQLite migrations are manual (no ORM); forgetting `onUpgrade` handler.
**How to avoid:** Version the database schema from day 1 (`version: 1` in `openDatabase`). Write `_onUpgrade` handler skeleton even if empty. Document migration path.
**Warning signs:** `DatabaseException` on app update.

## Code Examples

### BiographyFact Data Model
```dart
// Source: CONTEXT.md locked decision + existing CoachInsight pattern
enum FactType {
  salary, lppCapital, lppRachatMax, threeACapital, avsContributionYears,
  taxRate, mortgageDebt, canton, civilStatus, employmentStatus,
  lifeEvent, userDecision, coachPreference,
}

enum FactSource {
  document,    // From Phase 2 document extraction
  userInput,   // Manual entry in onboarding/wizard
  userEdit,    // Edited in privacy control screen
  coach,       // Extracted from coach conversation
}

class BiographyFact {
  final String id;           // UUID v4
  final FactType factType;
  final String? fieldPath;   // Maps to CoachProfile field (e.g., 'salaireBrutMensuel')
  final String value;        // Serialized value
  final FactSource source;
  final DateTime? sourceDate; // When the source document was dated
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> causalLinks;   // IDs of related facts
  final List<String> temporalLinks; // IDs of temporally linked facts
  final bool isDeleted;      // Soft delete for audit trail
  final String freshnessCategory; // 'annual' or 'volatile'

  // ... constructor, copyWith, toJson, fromJson
}
```
[ASSUMED: schema design based on CONTEXT.md decisions + existing CoachInsight pattern]

### Freshness Decay Service
```dart
// Source: existing confidence_scorer.dart _freshnessScore() + CONTEXT.md decay rules
class FreshnessDecayService {
  /// Annual fields: full weight for 12 months, linear decay to 0.3 at 36 months
  /// Volatile fields: full weight for 3 months, linear decay to 0.3 at 12 months
  static double weight(BiographyFact fact, DateTime now) {
    final age = now.difference(fact.updatedAt);
    final months = age.inDays / 30.44;

    if (fact.freshnessCategory == 'volatile') {
      if (months <= 3) return 1.0;
      if (months >= 12) return 0.3;
      return 1.0 - (months - 3) / (12 - 3) * 0.7;
    } else {
      // annual (default)
      if (months <= 12) return 1.0;
      if (months >= 36) return 0.3;
      return 1.0 - (months - 12) / (36 - 12) * 0.7;
    }
  }

  /// Returns true if fact should trigger a refresh prompt (BIO-08)
  static bool needsRefresh(BiographyFact fact, DateTime now) {
    return weight(fact, now) < 0.60;
  }

  /// Freshness category assignment for common field types
  static String categoryFor(FactType type) {
    switch (type) {
      case FactType.salary:
      case FactType.lppCapital:
      case FactType.lppRachatMax:
      case FactType.threeACapital:
      case FactType.avsContributionYears:
      case FactType.taxRate:
        return 'annual';
      case FactType.mortgageDebt:
        return 'volatile'; // Market rates change frequently
      default:
        return 'annual';
    }
  }
}
```
[ASSUMED: decay curve based on existing _freshnessScore() pattern + CONTEXT.md rules]

### Coach System Prompt Biography Section
```python
# Source: existing claude_coach_service.py pattern + CONTEXT.md BIO-04/BIO-07 rules
_BIOGRAPHY_AWARENESS = """\
BIOGRAPHY AWARENESS:
- The user's financial biography is in the memory block (BIOGRAPHIE FINANCIERE section).
- Reference biography facts ONLY when contextually relevant to the user's current question.
- Maximum 1 biography reference per response.
- ALWAYS use approximate amounts: "un peu moins de 100k" NOT "95'000 CHF".
- ALWAYS date your source: "selon ton certificat de mars 2025" or "d'apres ta derniere saisie".
- Use CONDITIONAL language for all biography-sourced data:
  * "Si ton salaire est toujours autour de..." (not "Ton salaire est...")
  * "La derniere fois, ton avoir LPP etait de..." (not "Tu as...")
- Facts marked [DONNEE ANCIENNE] are stale -- mention the age explicitly and suggest a refresh.
- NEVER cite: upload dates, filenames, exact amounts, employer names.
- If the user corrects a fact, acknowledge and suggest updating via the privacy screen.
"""
```
[ASSUMED: prompt template based on existing system prompt patterns in claude_coach_service.py]

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SharedPreferences for all memory | SharedPreferences (insights) + sqflite_sqlcipher (biography) | Phase 3 | Structured queries, encryption at rest, graph-like links |
| 50 FIFO insights (CoachMemoryService) | 50 insights + unlimited biography facts | Phase 3 | Richer cross-session context; insights are summaries, facts are structured data |
| MemoryContextBuilder 1500 chars | MemoryContextBuilder 1500 chars + AnonymizedBiographySummary 2K tokens | Phase 3 | More context for coach; privacy-safe partitioning |
| No user control over stored data | Privacy control screen with view/edit/delete | Phase 3 | nLPD compliance, user trust |

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | sqflite_sqlcipher 3.4.0 is compatible with current Flutter SDK version in project | Standard Stack | Medium -- version mismatch could require downgrade or alternative |
| A2 | path_provider is already in pubspec.yaml or can be added without conflicts | Standard Stack | Low -- standard Flutter dependency |
| A3 | iOS Keychain persists encryption key across reinstalls; Android KeyStore does not | Pitfalls | Medium -- key loss behavior may vary by device/OS version |
| A4 | 2K token budget (~8000 chars) is sufficient for meaningful biography summary | Architecture | Low -- can be tuned; existing memory block is 1500 chars |
| A5 | Volatile freshness category applies to mortgage/market-rate fields; annual to salary/LPP/AVS | Code Examples | Low -- category assignment is configurable |

## Open Questions

1. **path_provider in pubspec.yaml**
   - What we know: flutter_secure_storage is present; path_provider is commonly bundled but not confirmed
   - What's unclear: Whether it needs explicit addition
   - Recommendation: Check pubspec.yaml at plan execution time; add if missing

2. **Database file location on different platforms**
   - What we know: `getApplicationDocumentsDirectory()` is standard for iOS/Android
   - What's unclear: Web platform behavior (sqflite_sqlcipher does not support web)
   - Recommendation: Biography feature is mobile-only; web fallback can use in-memory or SharedPreferences subset

3. **Biography-to-CoachProfile synchronization direction**
   - What we know: CONTEXT.md says document extractions create biography facts; CoachProfile is the superset used by simulators
   - What's unclear: Whether biography facts should feed back into CoachProfile fields, or remain a parallel data layer
   - Recommendation: Biography facts FEED CoachProfile via BiographyProvider -- same pattern as current wizard answers. CoachProfile remains the consumer-facing model.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| flutter_secure_storage | BIO-02 encryption key | Yes | ^9.0.0 | -- (already in pubspec) |
| sqflite_sqlcipher | BIO-01, BIO-02 encrypted DB | No (not in pubspec) | 3.4.0 target | Must add via `flutter pub add` |
| path_provider | DB file path | Unknown | -- | Check at execution time |
| uuid | Fact IDs | Yes | already imported | -- |

**Missing dependencies with no fallback:**
- sqflite_sqlcipher must be added to pubspec.yaml (Wave 0 task)

**Missing dependencies with fallback:**
- None

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | flutter_test (built-in) + pytest (backend) |
| Config file | apps/mobile/flutter_test.yaml (if exists) |
| Quick run command | `cd apps/mobile && flutter test test/services/biography/` |
| Full suite command | `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BIO-01 | BiographyFact CRUD with links | unit | `flutter test test/services/biography/biography_repository_test.dart -x` | No -- Wave 0 |
| BIO-02 | Database opens with encryption key | unit | `flutter test test/services/biography/biography_encryption_test.dart -x` | No -- Wave 0 |
| BIO-03 | Anonymization rounds salary, strips PII, respects 2K limit | unit | `flutter test test/services/biography/anonymized_biography_test.dart -x` | No -- Wave 0 |
| BIO-04 | Coach output uses approximate amounts, no filenames | unit | `flutter test test/services/biography/coach_biography_integration_test.dart -x` | No -- Wave 0 |
| BIO-05 | Privacy screen displays facts, edit saves with source=userEdit | widget | `flutter test test/screens/profile/privacy_control_screen_test.dart -x` | No -- Wave 0 |
| BIO-06 | Freshness decay: annual 12mo, volatile 3mo | unit | `flutter test test/services/biography/freshness_decay_test.dart -x` | No -- Wave 0 |
| BIO-07 | Coach dates sources, uses conditional language | unit | `python3 -m pytest tests/test_biography_coach_guardrails.py -x` | No -- Wave 0 |
| BIO-08 | Refresh prompt when freshness < 0.60 | unit | `flutter test test/services/biography/biography_refresh_detector_test.dart -x` | No -- Wave 0 |
| COMP-02 | Stale data flagged, not presented as truth | unit+widget | `flutter test test/services/biography/stale_data_compliance_test.dart -x` | No -- Wave 0 |
| COMP-03 | Raw biography never in API calls | unit | `flutter test test/services/biography/biography_privacy_test.dart -x` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `cd apps/mobile && flutter test test/services/biography/`
- **Per wave merge:** `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q`
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `test/services/biography/biography_repository_test.dart` -- covers BIO-01, BIO-02
- [ ] `test/services/biography/anonymized_biography_test.dart` -- covers BIO-03, COMP-03
- [ ] `test/services/biography/freshness_decay_test.dart` -- covers BIO-06
- [ ] `test/services/biography/biography_refresh_detector_test.dart` -- covers BIO-08
- [ ] `test/screens/profile/privacy_control_screen_test.dart` -- covers BIO-05
- [ ] `tests/test_biography_coach_guardrails.py` (backend) -- covers BIO-07
- [ ] sqflite_sqlcipher + path_provider added to pubspec.yaml

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A -- biography is local, no auth layer |
| V3 Session Management | No | N/A |
| V4 Access Control | Yes | Encryption key in platform secure storage (Keychain/KeyStore); database encrypted at rest |
| V5 Input Validation | Yes | BiographyFact value validation; sanitization before DB write; SQL injection prevented by parameterized queries (sqflite API) |
| V6 Cryptography | Yes | AES-256-CBC via SQLCipher 4.10; key in flutter_secure_storage; never hand-rolled |

### Known Threat Patterns for Flutter + SQLite

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Plaintext database on disk | Information Disclosure | sqflite_sqlcipher encrypts entire DB file with AES-256 |
| Encryption key in SharedPreferences | Information Disclosure | Key stored in flutter_secure_storage (hardware-backed on modern devices) |
| PII leakage in LLM prompts | Information Disclosure | AnonymizedBiographySummary with field-type-aware rounding; ComplianceGuard validation |
| SQL injection via fact values | Tampering | sqflite parameterized queries (? placeholders); never string concatenation |
| Biography data exfiltration via API | Information Disclosure | Architecture constraint: BiographyRepository has no network methods; only AnonymizedBiographySummary enters HTTP requests |
| Stale data presented as current | Spoofing | FreshnessDecayService + COMP-02 dating requirement |

## Sources

### Primary (HIGH confidence)
- [pub.dev/sqflite_sqlcipher](https://pub.dev/packages/sqflite_sqlcipher) -- version 3.4.0, SQLCipher 4.10, API docs [VERIFIED: WebFetch]
- [pub.dev/sqflite](https://pub.dev/packages/sqflite) -- version 2.4.2, API compatibility reference [VERIFIED: WebFetch]
- [pub.dev/flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) -- version 10.0.0 latest (project uses ^9.0.0) [VERIFIED: WebFetch]
- Codebase: `apps/mobile/lib/services/coach/context_injector_service.dart` -- existing memory injection architecture [VERIFIED: codebase read]
- Codebase: `apps/mobile/lib/services/memory/coach_memory_service.dart` -- existing memory service pattern [VERIFIED: codebase read]
- Codebase: `apps/mobile/lib/services/memory/memory_context_builder.dart` -- existing context builder pattern [VERIFIED: codebase read]
- Codebase: `apps/mobile/lib/services/financial_core/confidence_scorer.dart` -- existing freshness decay [VERIFIED: codebase grep]
- Codebase: `apps/mobile/lib/models/coach_profile.dart` -- dataTimestamps field [VERIFIED: codebase grep]
- Codebase: `services/backend/app/services/coach/claude_coach_service.py` -- system prompt structure [VERIFIED: codebase read]

### Secondary (MEDIUM confidence)
- [sqflite_sqlcipher Medium article](https://medium.com/@sumaiah.mitu/secure-sqlite-database-in-flutter-using-sqflite-sqlcipher-ffccbb008743) -- implementation patterns [CITED: WebSearch result]

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- sqflite_sqlcipher verified on pub.dev; flutter_secure_storage already in project
- Architecture: HIGH -- existing codebase patterns (ContextInjectorService, CoachMemoryService, ComplianceGuard) well understood from code reading
- Pitfalls: MEDIUM -- key loss and migration pitfalls are well-documented in Flutter community; anonymization edge cases are project-specific
- Coach integration: HIGH -- claude_coach_service.py system prompt structure fully read and understood

**Research date:** 2026-04-06
**Valid until:** 2026-05-06 (stable domain -- encrypted local storage, no fast-moving APIs)
