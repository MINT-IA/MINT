# Deferred items — phase mint-illogism-fixes

Out-of-scope discoveries logged during execution. NOT fixed in the originating
plan (SCOPE BOUNDARY : only auto-fix issues directly caused by the current
task's changes).

| Date | Plan | File:line | Issue | Disposition |
|------|------|-----------|-------|-------------|
| 2026-06-11 | 02 | apps/mobile/lib/services/response_card_service.dart:983 | Accent FR pré-existant : `securite` → `sécurité` (commentaire « Coussin securite: 3-6 mois de charges »), introduit par commit `afc3e62d5` « Use plausible expenses for FRI and response cards ». Hors du diff plan-02 (édit limité aux lignes ~772-784). | Deferred — petit PR accent FR séparé. Ne pas corriger dans plan 02 (Karpathy #3, ligne non liée). |
| 2026-06-11 | 03 | apps/mobile/lib/services/response_card_service.dart:988 | Accent FR pré-existant : `securite` → `sécurité` (commentaire), commit `c214201d0`. Hors du diff plan-03 (édit limité aux lignes ~788-800). | Deferred — même PR accent FR que ci-dessus. Ne pas corriger (SCOPE BOUNDARY, ligne non liée). |
| 2026-06-11 | 03 | apps/mobile/lib/services/premier_eclairage_selector.dart:257,259 | Accent FR pré-existant : `securite` → `sécurité` + `depenses` + `recommandent` dans un string d'alerte d'épargne. Hors du diff plan-03 (édit limité aux lignes ~373-387). | Deferred — string user-facing à ré-accentuer (et idéalement i18n) dans un PR dédié. Ne pas corriger (SCOPE BOUNDARY + risque de toucher une string affichée non testée). |
| 2026-06-11 | 04 | apps/mobile/lib/services/financial_core/tax_calculator.dart:263 | Accent FR pré-existant : `specialiste` → `spécialiste` + `personnalisee` → `personnalisée` (string de disclaimer fiscal), commit `923a1a7e6`. Hors du diff plan-04 (édit limité à `estimate3aTaxImpact` ~532-570). | Deferred — string à ré-accentuer (idéalement i18n) dans un PR dédié. Ne pas corriger (SCOPE BOUNDARY + risque de toucher une string affichée). |
