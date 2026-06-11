# Deferred items — phase mint-illogism-fixes

Out-of-scope discoveries logged during execution. NOT fixed in the originating
plan (SCOPE BOUNDARY : only auto-fix issues directly caused by the current
task's changes).

| Date | Plan | File:line | Issue | Disposition |
|------|------|-----------|-------|-------------|
| 2026-06-11 | 02 | apps/mobile/lib/services/response_card_service.dart:983 | Accent FR pré-existant : `securite` → `sécurité` (commentaire « Coussin securite: 3-6 mois de charges »), introduit par commit `afc3e62d5` « Use plausible expenses for FRI and response cards ». Hors du diff plan-02 (édit limité aux lignes ~772-784). | Deferred — petit PR accent FR séparé. Ne pas corriger dans plan 02 (Karpathy #3, ligne non liée). |
