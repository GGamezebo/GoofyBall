#!/usr/bin/env bash
# One-time GitHub setup: labels, milestones, main protection.
# Needs GitHub CLI logged in with admin rights: gh auth login
# Usage: .github/setup/github_setup.sh [owner/repo]
set -euo pipefail
REPO="${1:-GGamezebo/GoofyBall}"
cd "$(dirname "$0")/../.."

# Labels from .github/labels.yml
while IFS= read -r line; do
  [[ -z "$line" || "$line" == \#* ]] && continue
  name="${line%%:*}"; rest="${line#*: }"
  color="${rest%% | *}"; desc="${rest#* | }"
  gh label create "$name" --repo "$REPO" --color "$color" --description "$desc" --force
done < .github/labels.yml

# Milestones from docs/roadmap.md stages (existing ones are skipped)
mk() { gh api "repos/$REPO/milestones" -f title="$1" -f description="$2" >/dev/null || true; }
mk "Stage 1 - Project skeleton" "Godot 4.7 skeleton from quizmatik: core/lib, HFSM, app_root, empty scenes runnable via F6, headless tests, CI, glow check in Compatibility"
mk "Stage 2 - Simulation core" "MatchSetup, presets, N players/teams, TwoTeamPoints and MultiZoneLives rules, determinism tests"
mk "Stage 3 - Effects system" "Modifier, BuffBase, BuffRegistry, EnvDirector, self_destruct; first buffs and events"
mk "Stage 4 - Presentation" "Jelly blob, glow, camera FX, HUD, touch controls"

# Protect main: PR only, no force push, no deletion
gh api -X PUT "repos/$REPO/branches/main/protection" --input - <<JSON
{
  "required_status_checks": null,
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 0, "dismiss_stale_reviews": true},
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
JSON
echo "Done: labels, milestones, main protection for $REPO"
