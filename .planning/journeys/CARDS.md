# Journey OS Cards

Generated from `.planning/journeys/records/*.json`. Do not edit directly.

## account_lifecycle_delete

- Title: Account lifecycle delete
- Tier: T0
- Status: live_proven
- Persona: fresh_disposable_staging_user, cadre_salarie_lpp_suisse_ready
- Entry state: User starts signed out, can recover password, register with disposable credentials, and reach authenticated privacy controls.
- Account state: Signed out at recovery/register entry, authenticated before privacy control, signed out again after account deletion.
- Success state: Recovery entry, registration, profile seal, privacy control, account deletion, and post-delete signed-out state all replay in one runtime proof.
- Negative assertions: Deleted account cannot keep an authenticated privacy surface visible., Email verification interstitial must not block the tested disposable staging account., Privacy delete controls must not remain visible after deletion.
- Routes: /auth/login, /auth/register, /auth/forgot-password, /profile/privacy-control, /profile/privacy
- APIs: POST /api/v1/auth/register, DELETE /api/v1/auth/account
- Runtime replay: account_lifecycle / auth / MINT iPhone 13 mini RvC / tools/simulator/flows/maestro-perfect-set/flow_jos001_account_lifecycle_seeded_delete.yaml
- Issues: JOS-001:verified/green
- Proof owner: mint-quality-gate
- Fix owner: mint-mobile
- Latest proof: green / runtime / 2026-06-26T20:05:41Z / 63220e05
- Latest artifact: .planning/journeys/evidence/account_lifecycle_delete/20260626T200541Z/result.xml

## coach_advice_turn

- Title: Coach advice turn
- Tier: T0
- Status: partial
- Persona: cadre_salarie_lpp_suisse_ready
- Entry state: Authenticated seeded Swiss salaried-LPP user opens Coach after the debug-only profile helper has persisted the same fixture.
- Account state: Authenticated staging account with first-experience gate completed by the E2E route helper.
- Success state: Coach answers the 2026 3a/LPP ceiling question with a visible current number, legal provenance, and no certainty-language regression.
- Negative assertions: Freshness fallback must not replace the cited 2026 answer., Banned LSFin certainty terms must stay absent., Coach must not render framework exceptions or overflow text.
- Routes: /coach/chat
- APIs: POST /api/v1/coach/chat
- Runtime replay: authenticated, top / auth / MINT iPhone 13 mini RvC / tools/simulator/flows/maestro-perfect-set/flow_jos004_coach_advice_turn_runtime.yaml
- Issues: JOS-004:verified/green
- Proof owner: mint-quality-gate
- Fix owner: mint-swiss-brain
- Latest proof: green / runtime / 2026-06-28T23:50:28Z / 52935411
- Latest artifact: .planning/journeys/evidence/runtime_replay/20260628T234759Z/coach_advice_turn/result.xml

## money_truth_spine

- Title: Money truth spine
- Tier: T0
- Status: live_proven
- Persona: cadre_salarie_lpp_suisse_ready
- Entry state: Seeded Swiss profile is persisted through the debug-only route helper before Budget setup edits fixed monthly charges.
- Account state: Local/debug runtime profile store is populated; the proof intentionally does not depend on account creation.
- Success state: Budget, Mon Argent, Rapport, and Coach expose the same persisted money truth snapshot after app restart.
- Negative assertions: Absurd captured values must not leak into visible money surfaces., Rapport must not duplicate the full Budget screen., Budget read model must survive restart before downstream checks.
- Routes: /budget, /mon-argent, /rapport, /coach/chat
- APIs: -
- Runtime replay: core / no-auth / MINT iPhone 13 mini RvC / tools/simulator/flows/maestro-perfect-set/flow_money_trust_chain_budget_mon_argent_rapport_coach.yaml
- Issues: JOS-002:verified/green
- Proof owner: mint-quality-gate
- Fix owner: mint-mobile
- Latest proof: green / runtime / 2026-06-27T00:38:40Z / 5d8b970c
- Latest artifact: .planning/journeys/evidence/money_truth_spine/20260627T003738Z/result.xml

## onboarding_first_value

- Title: Onboarding first value
- Tier: T0
- Status: partial
- Persona: cadre_salarie_lpp_suisse_ready, fresh_anonymous_swiss_user
- Entry state: Fresh anonymous user enters the MVP wedge, chooses the LPP rente-capital axis, and should reach first value before account creation.
- Account state: Anonymous local mode; account creation must remain after first value, not before the rente-vs-capital surface.
- Success state: Selecting the LPP rente-capital axis opens the first-value experience and can continue toward Coach or Home without a premature account gate.
- Negative assertions: Account-creation gate must not replace the first-value destination., Beta modal must not block the onboarding axis proof., The route helper must not rely on a release-only debug path.
- Routes: /onb, /retraite/rente-vs-capital, /coach/chat, /home
- APIs: -
- Runtime replay: core / no-auth / MINT iPhone 13 mini RvC / tools/simulator/flows/maestro-perfect-set/flow_mint2_first_experience_rente_capital_entry.yaml
- Issues: JOS-005:verified/green
- Proof owner: mint-quality-gate
- Fix owner: mint-mobile
- Latest proof: green / runtime / 2026-06-28T23:21:28Z / f7e92f87
- Latest artifact: .planning/journeys/evidence/runtime_replay/20260628T231957Z/onboarding_first_value/result.xml

## profile_privacy_control

- Title: Profile privacy control
- Tier: T0
- Status: partial
- Persona: julien_swiss, local_mode_profile_user
- Entry state: User opens profile privacy controls from local or authenticated profile surfaces with stored facts already present.
- Account state: Local mode or authenticated account can inspect stored profile data; destructive backend operations are separately contract-tested.
- Success state: Privacy control displays known stored facts and links to privacy center/settings; backend export/delete/consent replay remains a separate authenticated proof.
- Negative assertions: Known-data view must not collapse into the empty state when profile facts exist., Privacy center must keep an account deletion entry., Confidentiality settings must keep an in-app exit.
- Routes: /profile/privacy-control, /profile/privacy, /settings/confidentialite
- APIs: GET /api/v1/privacy/consent-status, POST /api/v1/privacy/export, POST /api/v1/privacy/delete
- Runtime replay: core / no-auth / MINT iPhone 13 mini RvC / tools/simulator/flows/maestro-perfect-set/flow_row24_privacy_control_runtime.yaml
- Issues: JOS-003:verified/green
- Proof owner: mint-quality-gate
- Fix owner: mint-mobile
- Latest proof: green / runtime / 2026-06-27T00:57:37Z / 104c92d1
- Latest artifact: .planning/journeys/evidence/profile_privacy_control/20260627T005708Z/result.xml
