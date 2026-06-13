# Mint North Star Experience v1

## Thesis

Mint is the calm Swiss financial lucidity dossier.

It helps a person understand their situation before making, delaying, or suffering a financial decision. It makes facts visible, implications understandable, uncertainty explicit, and control reachable.

Mint does not sell chat. Chat is a coach layer over evidence, calculations, state, and decision artifacts.

## Product Promise

Mint shows:

- what it understood;
- what is known, assumed, stale, or missing;
- what changes for the user;
- where data is stored and shared;
- what can be refined next;
- how to continue, save, reset, delete, or leave.

## Non-Promises

Mint is not:

- a generic chatbot;
- a regulated advisor;
- a broker, comparator, or product ranking engine;
- a KPI cockpit;
- a retirement-only app;
- a gamified score system;
- a black-box data collector.

## Core Surfaces

1. `Premier éclairage`: first pre-account clarity artifact.
2. `Aujourd'hui`: one current priority, one reason, one next action.
3. `Mon argent`: living map of money facts and implications.
4. `Plans / Décisions`: durable workbenches for major decisions.
5. `Dossier`: facts, documents, provenance, confidence, corrections.
6. `Profil & Confiance`: account, local/cloud state, reset, delete, sharing.
7. `Coach`: contextual layer opened from surfaces, not default home.

## First Experience

Flow:

1. intent or life event;
2. Swiss context guard;
3. minimal facts: canton/residence, household, work status, age band or birth year, approximate financial range only when needed;
4. `Premier éclairage` with known/assumed/missing, confidence, no naked number;
5. choice to continue locally, save the dossier, ask the coach, reset, or leave.

Account creation comes after value and means preservation. Apple can be primary UI, but non-Apple, refusal, local mode, and auth failure must remain first-class paths.

## State Grammar

Every material fact or insight must expose:

- source;
- freshness;
- confidence;
- storage location;
- sync state;
- AI sharing state;
- delete consequence.

Account states must be explicit: anonymous local, account with sync off, sync pending, sync on, conflict, delete pending, deleted/anonymized.

## AI Boundary

Deterministic code owns facts, calculators, assumptions, confidence, persistence, eligibility, and routing execution.

AI can detect intent, explain grounded artifacts, ask missing questions, summarize, and prepare handoff text. AI must not invent facts, compute financial truth, rank products, prescribe decisions, or generate unsupported UI.

## Architecture Direction

Recommended path: targeted refondation, not full rewrite.

Keep:

- Flutter shell while useful;
- route registry and route checks;
- `financial_core` as L1 calculation authority;
- backend lucidity payloads for L2-L4;
- `CoachProfile` as transitional hydration model.

Rebuild:

- typed `DataSpineSnapshot` as the only UX read model;
- single profile write pipeline with source/confidence/timestamp;
- account/cloud/reset/restore state machine;
- runtime feature flag registry with enforced kill switches;
- route topology around the core surfaces.

Cut or demote:

- chat-first landing;
- disconnected simulator routes;
- legacy redirects that lose semantic payload;
- achievements, score reveal, benchmarks, and catalogue-first explorer;
- public promises not generated from real data-flow evidence.

## Quality Bar

A screen is acceptable only if a user can answer in five seconds:

1. What matters here?
2. Why does it matter?
3. What does Mint know or assume?
4. What can I do next?
5. How do I leave, reset, or control my data?
