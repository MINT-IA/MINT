# MINT Brand — v2 Refondation Source

Design source artifacts for the v2 brand refondation. Consumed by **Phase 92 MVP-FONTS-TOKENS-V2** as design input (Supreme + Gambarino + Menthe-vive palette).

## Files

- `MINT v2 (2).html` — refondation identity (palette + slogan + typography)
- `MINT v2-print.html` — print-ready version of the above
- `MINT-brand (1).html` — full brand guidelines (wordmark, icon, grid, retired alternatives)
- `MINT-brand-print.html` — print-ready version of the above

## Status

- 2026-05-10 — tracked in repo during branch hygiene cleanup ; previously sat untracked at repo root + `docs/brand/`
- Will be consumed by Phase 92 plans as `read_first` design input ; theme tokens (`apps/mobile/lib/theme/colors.dart`, `apps/mobile/lib/theme/mint_text_styles.dart`) will reflect the locked palette + typography per W2 of Phase 92.

## DO NOT

- Edit these HTMLs directly — they are exports from the design tool. Re-export and replace.
- Reference at runtime — these are dev-time references only ; assets bundled via Phase 92 plans go to `apps/mobile/assets/`.
