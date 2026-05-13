# FIX-06 — MintShell ARB parity audit

**Status :** ✅ **PASS** (audit only, zero code change needed)

**Generated :** 2026-04-24

## Scope
Per `REQUIREMENTS.md` FIX-06 :
> Labels `l.tabAujourdhui / l.tabMonArgent / l.tabCoach / l.tabExplorer`
> DÉJÀ i18n-wired ([mint_shell.dart:50-65]), **audit seulement** : clés
> présentes dans fr/en/de/es/it/pt, pas de ASCII-only residue
> (pas rewrite, MEMORY.md était stale).

## Verification

### 1. Widget wiring confirmed
`apps/mobile/lib/widgets/mint_shell.dart` :
```dart
50:                label: l.tabAujourdhui,
55:                label: l.tabMonArgent,
60:                label: l.tabCoach,
65:                label: l.tabExplorer,
```
All 4 tab labels consume `AppLocalizations` lookups — no hardcoded strings.

### 2. ARB parity (6 languages)

| Lang | tabAujourdhui | tabMonArgent | tabCoach | tabExplorer |
|------|---------------|--------------|----------|-------------|
| fr | Aujourd'hui | Mon argent | Coach | Explorer |
| en | Today | My money | Coach | Explore |
| de | Heute | Mein Geld | Coach | Entdecken |
| es | Hoy | Mi dinero | Coach | Explorar |
| it | Oggi | I miei soldi | Coach | Esplora |
| pt | Hoje | Meu dinheiro | Coach | Explorar |

All 24 key/value pairs present.  Zero missing keys.  No duplicate definitions.

### 3. ASCII-residue check
- `fr` has `Aujourd'hui` (apostrophe correctly typed).
- All other labels either natively unaccented in target language, or proper loanwords ("Coach").
- No ASCII-flattened French in any ARB ("aujourdhui" without apostrophe, "creer" instead of "créer", etc. — none found).

### 4. MEMORY.md stale reference
`REQUIREMENTS.md` noted MEMORY.md had stale information claiming labels
needed re-wiring. Confirmed : labels are live + wired + i18n-complete
since Phase 7 (Landing v2) + Phase 26 (MintShell). FIX-06 was already
delivered by historical work; the audit formalises that fact.

## Result
**FIX-06 passes without any code change required.**

Phase 36 Success Criteria §4 satisfied :
> Les labels MintShell (`l.tabAujourdhui / l.tabMonArgent / l.tabCoach /
> l.tabExplorer`) sont présents dans les 6 ARB (fr/en/de/es/it/pt), sans
> ASCII-only residue — audit passé.

## Mark REQUIREMENTS.md
Update FIX-06 status `[ ]` → `[x]` at `.planning/REQUIREMENTS.md` line 117
with note "Audit passed 2026-04-24, no rewrite needed, see FIX-06 AUDIT.md".
