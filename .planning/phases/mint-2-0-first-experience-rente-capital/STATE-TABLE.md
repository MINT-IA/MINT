# Mint 2.0 First Experience — State Table

This table is the minimum state contract before code. It prevents a screen-only implementation from passing review.

| Initial state | Action | Expected state | Storage verified | Test provider/widget | Maestro / runtime | Device need | Risks |
|---|---|---|---|---|---|---|---|
| Fresh install, Keychain may contain old app namespace | Launch app | local dossier empty; stale secure keys purged or ignored by fresh-install sentinel | shared prefs / app support sentinel + secure storage namespace | provider unit test for fresh-install purge decision | cold launch screenshot and logs | real device later for Keychain/iCloud | Keychain can survive uninstall or restore |
| Anonymous, no dossier | Tap first CTA | three axes visible; no account gate | local draft only | landing/entry widget test | iPhone 13 mini flow | simulator first, device later | CTA returns to generic chat |
| Three axes visible | Tap `2e pilier : rente ou capital` | live flow opens; other axes remain signalétique | in-memory or local draft records selected axis | route/provider test | Maestro tap path | simulator | non-live axes accidentally calculate |
| Live rente/capital flow | Need age | ask birth date or age with reason | draft fact `birthDate` or `ageRange`, no account required | widget test copy + provider fact | screenshot for no clipping | iPhone 13 mini required before close | Apple account does not provide birth date |
| Live rente/capital flow | User skips age | qualitative explanation only; no personalized amount | missing-field readiness | unit test for blocked amount | Maestro skip path | simulator | app invents a number |
| Live rente/capital flow | User enters LPP amount/range | readiness updates; amount still gated by required fields | draft facts + calculation input audit | provider/calculator contract test | runtime value provenance screen | simulator | default amount leaks into result |
| Enough verified inputs | Request result | result shows value/range, unit, assumptions, sources, readiness, version, missing optional fields | calculation receipt stored in dossier | financial_core/backend test + widget test | screenshot / snapshot final | simulator then device | naked number or UI-only calculation |
| Result shown | Ask a follow-up in coach | coach navigates/explains same dossier item | answer linked to dossier entry | coach/dossier unit test | flow with answer revisit | simulator | chat becomes only storage |
| Result or dossier snippet visible | Counter/snippet updates | anonymous counters and dossier snippets do not overlap, duplicate, or collide | local counter + dossier projection | widget layout test for combined state | iPhone 13 mini screenshot | iPhone 13 mini simulator | mixed counters hide content |
| Anonymous active | Background / force kill | draft resumes or clearly says what was kept locally | local persistence layer | provider lifecycle test | sim kill/relaunch | simulator | silent loss or stale old conversation |
| Anonymous active | New discussion / reset | old conversation and draft unavailable after cold start | conversation store + profile draft + secure namespace where applicable | reset provider test | cold start flow | simulator | old conversation resurrects |
| Anonymous dossier | Create account, choose keep | migration attempts once; failure does not destroy local dossier | local dossier + backend claim receipt | auth provider migration test | auth mock flow | device later for Apple | migration failure loses data |
| Anonymous dossier | Create account, choose start over | account starts empty; old local draft purged after confirmation | local stores cleared | auth provider test | runtime reset path | simulator | ambiguous account state |
| Auth redirect in progress | App killed | return is idempotent; user can retry or cancel | pending auth transaction | auth provider test | sim kill during redirect if possible | device for Apple final | stuck auth sheet |
| Token expired / staging down | Continue account or save | local dossier remains; error is specific and retryable | token/session store | auth/backend error tests | offline/staging mock | simulator | generic failure loses trust |
| Logged in | Logout | local session cleared; saved backend dossier state not claimed deleted | auth/session store | provider test | runtime logout path | simulator | logout confused with delete |
| Logged in | Delete local data | local dossier, draft, conversation cleared; backend untouched unless explicit | local stores | provider test | cold start | simulator | deletion promise too broad |
| Logged in | Delete backend data | backend delete requested; local mirror cleared after success or marked pending | backend receipt + local mirror | backend/API test if touched | staging later | device not required first | partial delete hidden |
| iCloud Keychain / backup restore | App reinstall / restore | risk documented; app does not promise cloud erasure | secure storage behavior note | not closed by simulator | none | real device / TestFlight later | simulator falsely closes Keychain risk |
| iPhone 13 mini viewport | Every first-flow screen | no clipped buttons, counters, text, or bottom sheet | N/A | golden/widget layout where possible | screenshot and `idb ui describe-all` | iPhone 13 mini simulator minimum | large text/accessibility clipping |

Close condition: every row must be either covered by a named test/runtime artifact or explicitly left open with owner and reason.
