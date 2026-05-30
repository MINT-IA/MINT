# Phase 33 Summary — 3a Onboarding Tax Copy Guard

## What Changed

- Added `apps/mobile/test/screens/onboarding/mvp_wedge/mint_scene_3a_levier_test.dart`.
- Updated `MintScene3aLevier` copy:
  - Before: "Ce montant retombe sur ton compte chaque année, si tu le fais."
  - After: "Ce versement peut réduire ton impôt, selon ton canton et ton revenu."
  - Label changed from "économie fiscale annuelle" to "économie fiscale estimée".

## Why

A 3a contribution creates a deductible amount; it does not guarantee a cash return. The previous wording was too strong for a fintech trust surface and too close to the exact confusion observed in the simulator screenshots.

## Result

The onboarding scene still teaches the 3a lever, but now uses a bounded, legally safer statement that preserves user lucidity.
