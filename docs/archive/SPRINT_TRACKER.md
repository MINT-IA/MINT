# MINT Sprint Progress Tracker

> Extracted from CLAUDE.md for context diet. This file is the canonical sprint history.

| Sprint | Module | Backend | Flutter | Tests | Commit |
|--------|--------|---------|---------|-------|--------|
| S0-S8 | Core + Budget + RAG + Bank Import | done | done | done | various |
| S9 | Job Change LPP Comparator | done | done | done | `6e37675` |
| S10 | Divorce + Succession | done | done | done | `92bb677` |
| S11 | Proactive Coaching Engine | done | done | done | `8e2f2d3` |
| S12 | Sociological Segments | done | done | done | `3eb7a00` |
| S13 | LAMal Franchise Optimizer | done | done | done | `1ef929d` |
| S14 | Open Banking bLink/SFTI | done | done | done | `49c64be` |
| S15 | LPP Deep Dive | done | done | done | `8259894` |
| S16 | 3a Deep + Debt Prevention | done | done | done | `aa9b607` |
| S17 | Mortgage + Real Estate | done | done | 68 tests | `71460f9` |
| S18 | Independants complet | done | done | 66 tests | `5ed7c24` |
| S19 | Chomage + Premier emploi | done | done | 72 tests | `fb8a035` |
| S20 | Fiscalite avancee (26 cantons) | done | done | 53 tests | `4bde23a` |
| S21 | Retraite complete | done | done | 50 tests | `9005cfe` |
| S22 | Mariage + Naissance + Concubinage | done | done | done | various |
| S23 | Expatriation + Frontaliers | done | done | 87 tests | `868cb02` |
| S24 | Housing Sale + Donation (18/18 events) | done | done | done | `a16d5eb` |
| S25 | Integration & Discoverability | done | done | 1314 tests | `b59909f` |
| S26 | Post-Wizard Routing + NextSteps | done | done | 1357 tests | `637854c` |
| S27 | Educational Insert Wiring + Content | done | done | 1576 tests | `d1584e1` |
| S28 | SafeMode Enforcement + Compliance Tests | done | done | 1596 tests | `54026e3` |
| S29 | Smoke Test Coverage (26 screens) | done | done | 52 Flutter tests | `968f972` |
| S30 | Disability Gap Service (Chantier 3) | done | done | 1629 tests | `4d6f317` |
| S31-S33 | Arbitrage modules (rente vs capital, 3a, LPP buyback) | done | done | done | various |
| S34 | ComplianceGuard (25+ adversarial tests) | done | done | done | various |
| S35 | Coach Layer V1 (BYOK + fallback templates) | done | done | done | various |
| S36-S37 | FRI Calculator + Monte Carlo simulations | done | done | done | various |
| S38-S39 | FRI UI + tornado sensitivity analysis | done | done | done | various |
| S40 | Data Acquisition OCR (document scanning) | done | done | done | various |
| S41 | Rente vs Capital screen (UX masterplan hero) | done | done | done | various |
| S42 | Social insurance constants centralization | done | done | done | various |
| S43 | i18n foundation (6-language ARB, S.of(context)) | done | done | done | various |
| S44 | Intelligence branchement (arbitrage engine) | done | done | done | `06a7627` |
| S45 | Dashboard "film pas photo" (waterfall, narrative) | done | done | done | `57f4781` |
| S46 | Enhanced confidence scoring (4-axis) | done | done | 20 tests | `5d96840` |
| S47 | dataTimestamps wiring (per-field timestamps) | done | done | done | `a294eb2` |
| S48 | SLM audit + codebase audit + constants | done | done | done | `8dfc28c` |
| S49 | Navigation V1 (3 tabs, 85 routes, -3213 lines) | done | done | done | `24b6e25` |
| S50 | Prod readiness (v0.1.0, tests, i18n, docs) | done | done | in progress | in progress |

## Baselines (updated 2026-03-17)

- **Production version**: v0.1.0
- **Navigation**: 3 tabs (Pulse, Mint, Moi), 85 routes
- **Backend test baseline**: 84 tests (pytest)
- **Flutter tests**: 235 tests
- **Flutter analyze**: 0 errors
- **i18n**: 6 locales (fr, de, en, es, it, pt) — ~2800+ keys, ~5600 lines in app_fr.arb
- **Screens**: ~100
- **Services**: ~124
- **Widgets**: ~211
- **Financial Core**: unified AVS/LPP/Tax/FRI/Monte Carlo/Arbitrage/Confidence calculators
- **Autoresearch skills**: 10 (5 existing + 5 new)
