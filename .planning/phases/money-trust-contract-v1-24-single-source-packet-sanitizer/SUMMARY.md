# Phase 24 — Summary

## Changed

- `coach_chat.py` now delegates CoachContextPacket sanitation to the shared `context_packet_sanitizer.py`.
- The duplicated local packet allowlists and helper functions were removed from `coach_chat.py`.
- Added a parity test proving:
  - the endpoint wrapper returns the same output as the shared sanitizer;
  - `_sanitize_profile_context({"coach_context_packet": ...})` uses the same shared output.

## Why

Mint's trust layer depends on a stable data contract between mobile Data Spine, backend coach tools, RAG, and narrative output. Two independent sanitizers made it too easy for one path to accept a fact while another path dropped it.

## Result

One authoritative backend sanitizer remains for CoachContextPacket. Endpoint compatibility is preserved through the wrapper.

