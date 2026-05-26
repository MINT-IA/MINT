# Phase 26 — Mobile Backend Packet Fixture

## Goal

Freeze a representative mobile `CoachContextPacket.toSafeMap()` payload as a backend fixture so future allowlist changes cannot silently break the Flutter→Python data contract.

## Scope

- Add `services/backend/tests/fixtures/mobile_coach_context_packet_v1.json`.
- Test that the backend shared sanitizer keeps budget, situation, 3a, missing-field, trajectory, and next-question fields.
- Test that currently unsupported mobile-only `readiness` remains intentionally dropped.

## Why

The user-visible coach and budget output now depends on the packet as the trusted current-data source. The contract needs a frozen fixture, not only hand-built unit dictionaries.

