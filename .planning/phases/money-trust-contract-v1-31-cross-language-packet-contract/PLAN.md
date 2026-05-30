# Phase 31 — Cross-Language Packet Contract

## Goal

Prevent mobile and backend CoachContextPacket allowlists from drifting.

## Scope

- Parse the Dart `CoachContextPacketService.allowedFactIds` constant from backend tests.
- Compare it to the Python backend sanitizer `_ALLOWED_IDS`.
- Keep existing mobile tests proving emitted facts stay inside the Dart allowlist.

## Why

The mobile packet is now the trusted source for budget/coach output. If Flutter emits a fact id that Python drops silently, Mint can become incoherent again without a visible compile error.
