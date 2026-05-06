# R2 Goldens Manifest Schema (PERS-06, v2.13 Phase 90)

## Why R2 + manifest

Per panel-locked architecture (`.planning/decisions/2026-05-05-persona-narrative-scenario-coverage-panel.md`) :

> Goldens to **R2 bucket `mint-goldens/`** (NOT git, NOT git-lfs). 50 scripts × 5 checkpoints × 6 langs × 2 themes ≈ 5.4 GB per golden set. R2 = $0.015/GB/mo + zero egress. Manifest with hashes lives in git ; goldens themselves are content-addressed in R2 and pulled on-demand.

Cloudflare R2 is the storage primitive. Manifest is the git-tracked pointer.

## Bucket layout

```
mint-goldens/
├── julien_swiss/
│   ├── fr/
│   │   ├── light/
│   │   │   ├── 00-cold-launch.png         # content-addressed by sha256
│   │   │   ├── 01-landing.png
│   │   │   ├── 02-anon-chat-opener.png
│   │   │   ├── 03-after-turn1.png
│   │   │   ├── 04-eclairage-card.png
│   │   │   └── 05-register-cta.png
│   │   └── dark/                          # Phase 91+ optional theme
│   ├── de/
│   └── en/
├── lauren_expat_us/
├── sofia_independent/                     # Phase 92 JDEF
├── anna_widow/                            # Phase 92 JDEF
├── jennifer_fatca/                        # Phase 92 JDEF
└── pierre_late_career/                    # Phase 92 JDEF
```

## Manifest file (`tools/simulator/goldens/manifest.json`)

Lives in git. Sourced by walker on golden-bake mode. Format :

```json
{
  "schema_version": "1.0",
  "generated_at": "2026-05-06T07:30:00Z",
  "r2_bucket": "mint-goldens",
  "r2_endpoint": "https://<account-id>.r2.cloudflarestorage.com",
  "personas": {
    "julien_swiss": {
      "fr": {
        "light": {
          "00-cold-launch.png": {
            "sha256": "abc1234...64-char...def",
            "bytes": 149551,
            "baked_at": "2026-05-05T21:13:46Z",
            "walker_run_id": "2026-05-05-211306-73afa3cb",
            "ssim_threshold": 0.96
          },
          "01-landing.png": { "sha256": "...", "bytes": 149551, "baked_at": "...", "walker_run_id": "...", "ssim_threshold": 0.96 },
          "02-anon-chat-opener.png": { "sha256": "...", "bytes": 249504, "baked_at": "...", "walker_run_id": "...", "ssim_threshold": 0.96 },
          "03-after-turn1.png": { "sha256": "...", "bytes": 161381, "baked_at": "...", "walker_run_id": "...", "ssim_threshold": 0.96 },
          "04-eclairage-card.png": { "sha256": "...", "bytes": 164061, "baked_at": "...", "walker_run_id": "...", "ssim_threshold": 0.96 },
          "05-register-cta.png": { "sha256": "...", "bytes": 163894, "baked_at": "...", "walker_run_id": "...", "ssim_threshold": 0.96 }
        }
      }
    }
  }
}
```

## Field semantics

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `sha256` | string (64 hex) | yes | content address ; matches R2 object key suffix |
| `bytes` | int | yes | sanity check on download |
| `baked_at` | RFC3339 | yes | when the golden was captured + accepted |
| `walker_run_id` | string | yes | the walker run that produced this golden |
| `ssim_threshold` | float | yes | per-image override of the default 0.96 |

## Bake / refresh procedure

1. `bash tools/simulator/walker_premier_eclairage.sh --archetype julien_swiss --no-dry-run --bake-golden`
2. Walker captures 6 SHA-distinct screenshots → uploads to R2 keyed by sha256 → updates manifest.json
3. Reviewer asserts the captured screenshots match expected (visual review).
4. `git add tools/simulator/goldens/manifest.json && git commit -m "feat(goldens): bake julien_swiss FR light"`
5. Subsequent walker runs in `--diff-against-goldens` mode pull from R2 by sha256, run SSIM, fail if < threshold.

## Refresh policy (carry from `cache/replay/SCHEMA.md`)

Goldens are refreshed when :
- Brand line changes (e.g. landingV3Hero update — Phase 73)
- Éclairage card layout panel-relock (Phase 72 → Phase 7X)
- New archetype lands with first-time bake
- Golden becomes stale per nightly diff > 30 days old AND walker green continues

Refresh = `--bake-golden --force`.

## Auth

R2 access via Cloudflare API token in keychain :
```bash
security find-generic-password -s MINT_R2_ACCESS_KEY_ID -w
security find-generic-password -s MINT_R2_SECRET_ACCESS_KEY -w
```

`tools/simulator/r2_client.py` (Phase 91) wraps the `boto3` S3-compatible client pointed at R2 endpoint. Returns presigned URLs for walker download. Never logs tokens.

## Hard rules

1. **Goldens NEVER in git.** Only the manifest (with hashes) is in git. CI lints `tools/checks/goldens_not_in_git.py` — fails commit if any `*.png` lands under `tools/simulator/goldens/<persona>/<lang>/<theme>/`.
2. **R2 keys are content-addressed.** Same SHA = same image, regardless of persona/lang. Saves storage on cross-persona dups (e.g. cold-launch screen often identical across archetypes).
3. **SSIM threshold is per-image, not global.** Some screens (animations, anti-aliased gradients) need 0.94 ; tightly-locked editorial screens (Phase 73 hero) get 0.98.
4. **No flake-retry on golden diff.** SSIM < threshold = real visual regression. The codesign flake retry (Phase 86 audit) is OFF for visual diff.

## Status

- Schema : SHIPPED this commit.
- R2 bucket provisioning : DEFERRED to Phase 91 (operational, requires Cloudflare account setup ; not a Phase 90 line item).
- Bake/diff CLI wiring in walker : DEFERRED to Phase 91.
- For Phase 90 : the schema is the contract ; Phase 90 ships goldens as
  empty manifest (no images baked yet — walker `--diff-against-goldens`
  mode skipped per existing « skip diff: golden not present » fall-through
  in `walker_premier_eclairage.sh`).
