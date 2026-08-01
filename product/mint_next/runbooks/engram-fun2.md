# Engram/FUN2 backup and recovery runbook

## Invariants

- Keep the live database on local APFS while FUN2 remains removable.
- Never reuse the historical unencrypted `engram` recovery directory.
- Never place a passphrase, database, JSON export, or raw memory in Git.
- A successful backup is not a successful restore.
- Stop all Engram MCP/server processes before any live cutover.

## Local configuration

Define outside Git:

```bash
export ENGRAM_DATA_DIR="$HOME/.engram"
export MINT_ENGRAM_VAULT_BUNDLE="<encrypted sparsebundle on FUN2>"
```

The sparsebundle password belongs in the macOS login keychain, not an
environment file. Mounting requires the dedicated keychain service.

## Backup

1. Run `engram doctor --json` and retain the result outside Git.
2. Run SQLite `PRAGMA integrity_check` on the live database.
3. Mount the encrypted sparsebundle.
4. Use SQLite `.backup`; never copy a live WAL database with `cp`.
5. Export Engram JSON as a second recovery format.
6. Record counts, SHA-256 hashes, and integrity status in a sanitized receipt.
7. Detach the sparsebundle.

## Restore drill

1. Create a protected local temporary Engram data directory.
2. Restore the SQLite backup as `engram.db`.
3. Run full SQLite integrity, `engram stats`, and a known search probe.
4. Compare observations and sessions with the receipt.
5. Test JSON import into a separate empty data directory.
6. Record failures honestly; do not repair the only backup in place.

## Cutover gate

Live cutover stays forbidden until all conditions in `foundation.yaml` pass,
including mount-loss behavior and rollback to the local database. A non-author
reviewer must inspect the commands, receipt, and restored search result.
