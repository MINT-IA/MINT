#!/usr/bin/env bash
# Setup branch protection rules for MINT
# Usage: ./scripts/setup-branch-protection.sh
#
# Requires: gh CLI authenticated (gh auth login)
#
# What this does:
#   - Requires PR to merge into main (no direct push)
#   - Requires CI Gate to pass before merge
#   - Blocks force-push on main
#   - Requires 1 approval on PRs (optional, can be 0 for solo dev)
#   - Auto-deletes branches after merge

set -euo pipefail

REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
echo "Configuring branch protection for: $REPO"

# ─── Branch protection on main ────────────────────────────────
echo "Setting up branch protection on 'main'..."

gh api \
  --method PUT \
  "repos/${REPO}/branches/main/protection" \
  --input - <<'EOF'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["CI Gate"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "required_approving_review_count": 0,
    "dismiss_stale_reviews": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_linear_history": true
}
EOF

echo "Branch protection configured."

# ─── Auto-delete head branches ────────────────────────────────
echo "Enabling auto-delete of merged branches..."

gh api \
  --method PATCH \
  "repos/${REPO}" \
  --field delete_branch_on_merge=true

echo ""
echo "Done. Protection rules on 'main':"
echo "  - PR required (no direct push)"
echo "  - CI Gate must pass before merge"
echo "  - Force-push blocked"
echo "  - Linear history (rebase only, no merge commits)"
echo "  - Merged branches auto-deleted"
echo ""
echo "To test: try 'git push origin main' directly — it should be rejected."
