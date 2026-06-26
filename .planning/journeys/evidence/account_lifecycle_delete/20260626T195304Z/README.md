# JOS-001 account lifecycle runtime proof

- Run: `20260626T195304Z`
- Verified commit: `e3442103431404cd14b13d847aa119610ae74755`
- Device: iPhone 17 Pro simulator, iOS 26.2
- Flow: `tools/simulator/flows/maestro-perfect-set/flow_jos001_account_lifecycle_seeded_delete.yaml`
- Result: passed, 1 flow, 0 failures, 72s

Command shape:

```bash
MAESTRO_HARD_LIMIT=360 MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS=.planning/runtime-evidence/jos001-account-lifecycle-20260626T195304Z \
bash tools/simulator/maestro_with_watchdog.sh test \
  --format junit \
  --output .planning/runtime-evidence/jos001-account-lifecycle-20260626T195304Z/result.xml \
  --env MINT_E2E_EMAIL=<fresh disposable e2e email> \
  --env MINT_E2E_PASSWORD=<redacted> \
  tools/simulator/flows/maestro-perfect-set/flow_jos001_account_lifecycle_seeded_delete.yaml
```

Runtime scope proven:

- public recovery entry `/auth/forgot-password`;
- real account creation through `/auth/register`;
- real onboarding profile seal required by the authenticated route guard;
- `/profile/privacy-control` render under the created account;
- `/profile/privacy` delete-account entry and confirmation;
- post-delete signed-out recovery entry with no delete row visible.
