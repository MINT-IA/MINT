Everything checks out against the live code. My verification confirmed: `/scan?type=lppCertificate` correctly resolves to `DocumentScanScreen(initialType: DocumentType.lppCertificate)` (`app.dart:1196-1200`, `document_scan_screen.dart:238`); `pillar3aBalance` → `q_3a_total` is a stock, not a contribution (`coach_profile_provider.dart:3492`); `_validRemoteAmount` enforces `0 ≤ x ≤ 10M` and finiteness (`:2281`); and the strict-LPP precondition runs inside the atomic canonical mutation.

Product/domain verdict: PASS

## Summary of what this change does
It wires the coach's inline `ask_user_input` amount picker (salary / LPP / 3a) to the canonical Data Ledger with provenance, replacing a previously **broken** write path. The life events touched are progressive data collection for **salary (AVS/LPP/tax base), LPP avoir, and 3a savings** — the minimum inputs for the retirement/fiscal projection spine. No Swiss legal rule or threshold is computed or asserted here; it is a data-capture primitive.

## P0 findings
None.

## P1 findings
None. The change is domain-coherent and, notably, fixes a facade-without-wiring defect rather than introducing one (see P2-1).

## P2 findings
- **Salary field previously dropped silently (now fixed — worth flagging as the reason PASS is confident).** Before this diff, the inline `salaireBrut` picker called `_updateProfileField('salaireBrut', …)`, but `_updateProfileField` only had a `case 'salary'` (which wrote to the *net* income field `q_net_income_period_chf` despite a "brut annuel" label). So the salary picker either wrote nothing or wrote gross into a net slot. The new code (`coach_chat_screen.dart` `_handleInputSubmitted`) maps `salaireBrut → incomeGrossYearly → q_gross_salary_annual`, which is the correct gross base for AVS/LPP/tax. Net improvement.
- **LLM-controlled `prompt_text` vs fixed annual semantics.** `widget_renderer.dart` renders `ChatAmountInput` for `salary`/`salaireBrut` with a default label "Ton revenu brut annuel", but the value is *always* interpreted as gross-annual regardless of `prompt_text`. If the backend/LLM prompts for a monthly figure, the ledger silently stores it as annual. The default label mitigates this, but consider ignoring/validating `prompt_text` for amount fields or forcing the annual label. Data-quality, not correctness of the current path.
- **13th-month division.** Stored gross annual is divided by `q_nombre_mois` (12/13) to derive `salaireBrutMensuel`. Correct only if the user's entered annual already includes the 13th salary. Pre-existing behavior, but the inline prompt gives no hint. Cosmetic/UX.
- **Dead `'salary'` branch in `_displayTextForInput`** (`coach_chat_screen.dart`): field is normalized to `salaireBrut` upstream, so the `case 'salary'` echo is unreachable. Minor cleanup.

## Swiss domain review
- **AVS/LPP/tax (salary):** gross-annual is the correct determinant for the 1st-pillar contribution base, LPP coordinated salary, and taxable income. Storing to `q_gross_salary_annual` is coherent. No threshold/constant is asserted, so nothing to mark unverified.
- **LPP (avoir):** stored as a total stock (`_coach_avoir_lpp`), not split obligatoire/surobligatoire — consistent with existing scan semantics, and tests assert the oblig/suroblig keys are not fabricated. The **strict LPP authority guard** (typed certificate evidence outranks a free-typed amount, offering a scan-reconciliation handoff) is exactly the single-source-of-truth behavior expected; it fails closed and atomically.
- **3a:** stored as accumulated balance (`q_3a_total`), correctly *not* as annual contribution (`q_3a_annual_contribution`) — avoids the classic 3a stock/flow confusion. No plafond (7'258/8'056) is asserted here.
- **Not affected:** mortgage, insurance/LAMal, succession/donation, disability, cantonal tax logic — untouched by this diff.

## Mint product logic review
This moves Mint *toward* the ledger → DataQuest → scenario → dossier spine. It closes a real leak in the ledger write (salary), records userInput provenance with timestamps and survives cold reload (integration + contract tests prove it), removes the answered path from `coachBackendUnknownPaths` so the coach won't re-ask a known fact, and writes to the ledger before echoing back into the conversation. Compliance language is purely factual ("… déclaré : CHF …") with no advice, ranking, guarantee, or product recommendation. The reconciliation CTA is a specialist/data-quality handoff, not advice. Provenance distinguishes known (userInput, timestamped) from external as-of date (null for manual entry), which is correct.

Evidence base: `coach_profile_provider.dart:3357-3401` (write result + strict guard), `:3492` (3a stock), `:2281-2285` (amount bounds), `chat_inline_inputs.dart` (error/reconcile UI, `Future`-returning submit), `coach_chat_screen.dart` `_handleInputSubmitted` (await-before-echo), `app.dart:1192-1201` + `document_scan_screen.dart:238` (reconcile route wired), and `coach_inline_amount_write_contract_test.dart` (atomicity, cold-reload provenance, ceiling, negative/non-finite rejection, retry-once, LPP conflict vs transient failure).
