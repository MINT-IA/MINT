# MINT CI/CD Reference

> Extracted from CLAUDE.md for context diet. See also MEMORY.md for pitfalls.

## Pipelines (fully operational — `56701d2`)

| Workflow | Trigger | Runner | Status |
|----------|---------|--------|--------|
| **CI** (`ci.yml`) | push (any branch) | ubuntu | Backend pytest + Flutter analyze/test |
| **Deploy Backend** (`deploy-backend.yml`) | push main (`services/backend/**`) | ubuntu | Railway auto-deploy |
| **TestFlight** (`testflight.yml`) | push main (`apps/mobile/**`) + manual | macos-15 | Build iOS + Upload TestFlight |

## TestFlight Pipeline

- **Signing**: Fastlane Match (git-based, repo `Julienbatt/mint-certificates`)
- **Auth**: App Store Connect API key (Key ID `6TZCV5S346`)
- **CI keychain**: `setup_ci` (Fastlane built-in)
- **Build flow**: `flutter build ios --no-codesign` -> Match -> `update_code_signing_settings` -> `build_app` -> `upload_to_testflight`
- **Provisioning**: Manual signing, profile `match AppStore ch.mint.app`
- **TestFlight group**: "Beta Testeurs"

## Required GitHub Secrets

- `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`
- `MATCH_GIT_URL`, `MATCH_PASSWORD`, `MATCH_GIT_BASIC_AUTHORIZATION`
- `KEYCHAIN_PASSWORD`
- `RAILWAY_TOKEN`, `RAILWAY_API_TOKEN`, `RAILWAY_SERVICE_ID`, `API_BASE_URL`, `BACKEND_HEALTHCHECK_URL`
