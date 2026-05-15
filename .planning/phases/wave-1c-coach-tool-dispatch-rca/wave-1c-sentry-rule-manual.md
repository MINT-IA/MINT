---
description: Manual deploy steps for the wave-1c Sentry tripwire alarm rule. Auto-deploy was skipped because SENTRY_AUTH_TOKEN was unset in the executor environment.
phase: wave-1c-coach-tool-dispatch-rca
wave: A
task: A.6
type: ops-runbook
status: AWAITING_JULIEN_DEPLOY
---

# Wave 1c — Sentry Tripwire Alarm Rule (Manual Deploy)

## Why this file exists

Wave 1c Task A.6 attempted to deploy a Sentry alert rule via the Sentry REST API to fire on the new `coach.citation.tool_use_missing` breadcrumb category emitted by `_emit_tool_use_enforcement_breadcrumb` (PR #634). The auto-deploy path (Option A) requires `SENTRY_AUTH_TOKEN` in the local environment — it was unset, so the executor fell back to Option B (this manual artifact) per the plan's caveat clause.

Once the rule is live, every REJECT verdict from `_enforce_tool_use_for_citations` triggers a paged alert when its rate exceeds the threshold below.

## Breadcrumb the rule fires on

- **Category** : `coach.citation.tool_use_missing`
- **Level** : `warning`
- **Message format** : `tool_use_missing_for_citation:<short>` (e.g. `tool_use_missing_for_citation:retirement_projection`)
- **Payload schema** :
  ```json
  {
    "placeholder_name": "<short, e.g. retirement_projection>",
    "retry_count": 0_or_1,
    "narrator_tool_count": <int>
  }
  ```
- **Source** : `services/backend/app/api/v1/endpoints/coach_chat.py::_emit_tool_use_enforcement_breadcrumb` (PR #634, squash sha `bc02092500db6744486d326fa94c39c41d5aaeb5`).

## Steps for Julien

### Option A — Sentry UI (recommended)

1. Open https://sentry.io/organizations/<org-slug>/alerts/rules/ (the org slug for MINT — likely `mint` or `mint-ia`).
2. Click **Create Alert Rule** → **Issue Alert**.
3. Project : pick the MINT backend project (likely `backend` or `mint-backend`).
4. **When** : `An issue is seen` (or `An event is seen` for a faster signal).
5. **If** : add filter
   - **Filter type** : `The event's [tags] value [equals] [coach.citation.tool_use_missing]`
   - OR use the breadcrumb-category filter if Sentry exposes one in your plan tier.
6. **Frequency** : 10 events per 1 hour (tripwire threshold — adjust after the post-deploy probe lands).
7. **Then** : send notification to Julien (email or Slack — pick the channel that wakes you).
8. **Name** : `coach citation tool_use missing — Wave 1c tripwire`.
9. **Save**.

### Option B — Sentry REST API (if you set SENTRY_AUTH_TOKEN locally and want to avoid the UI)

```bash
ORG_SLUG="<your-org-slug>"
PROJ_SLUG="<your-backend-project-slug>"
SENTRY_AUTH_TOKEN="<your-token-from-https://sentry.io/settings/account/api/auth-tokens/>"

RULE_PAYLOAD='{
  "name": "coach citation tool_use missing — Wave 1c tripwire",
  "actionMatch": "all",
  "filterMatch": "all",
  "frequency": 60,
  "conditions": [
    {
      "id": "sentry.rules.conditions.event_frequency.EventFrequencyCondition",
      "interval": "1h",
      "value": 10
    }
  ],
  "filters": [
    {
      "id": "sentry.rules.filters.tagged_event.TaggedEventFilter",
      "key": "breadcrumb.category",
      "match": "eq",
      "value": "coach.citation.tool_use_missing"
    }
  ],
  "actions": [
    {
      "id": "sentry.rules.actions.notify_email.NotifyEmailAction",
      "targetType": "Member",
      "targetIdentifier": "<your-sentry-member-id>"
    }
  ]
}'

curl -s -X POST \
  -H "Authorization: Bearer $SENTRY_AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$RULE_PAYLOAD" \
  "https://sentry.io/api/0/projects/$ORG_SLUG/$PROJ_SLUG/rules/" | python3 -m json.tool
```

The response will include an `id` field — record it here below as **Rule ID**.

**Caveat on the filter shape** : if the POST returns 400 with a filter-validation error, Sentry's issue-alert filter for breadcrumb category may not be `TaggedEventFilter` with `key=breadcrumb.category` in your Sentry tier. Workaround : add an explicit Sentry tag in `_emit_tool_use_enforcement_breadcrumb` (one-line follow-up commit on a small PR) :
```python
sentry_sdk.set_tag("coach_citation_tool_use_missing", "1")
```
Then update the filter to match that tag instead.

## Verification once deployed

Visit https://sentry.io/organizations/<org-slug>/alerts/rules/<proj-slug>/<rule-id>/ and confirm `status == "active"`.

After the dev→staging merge (PR #635) lands and Railway redeploys, fire the live probe (see `.planning/phases/wave-1c-coach-tool-dispatch-rca/wave-1c-A-PLAN.md` §verification). If the fix is live, no `coach.citation.tool_use_missing` breadcrumbs fire and the rule is silent — that's the expected steady state. If the rule fires, the fix has regressed and Wave 1c must reopen.

## Record (fill once deployed)

- **Rule ID** : `<paste from Sentry UI or API response>`
- **Sentry rule URL** : `https://sentry.io/organizations/<org-slug>/alerts/rules/<proj-slug>/<rule-id>/`
- **Deployed at** : `<timestamp>`
- **Deployed by** : `<julien>`

## Re-deploy

If the rule is ever disabled, re-deploy by repeating the steps above. The rule definition is verbatim above so it can be re-created identically.

## Why fallback to manual

`SENTRY_AUTH_TOKEN` was unset in the executor environment when Task A.6 ran. Auto-deploy via the Sentry REST API requires the token. Per Task A.6 CAVEAT clause, fallback to manual deploy is non-blocking on the Wave A PR merge — Wave A.4 has already merged (PR #634, squash sha `bc02092500db6744486d326fa94c39c41d5aaeb5`) and the breadcrumb wire is live in code. The manual step here is only the operational tripwire that pages on rejects.
