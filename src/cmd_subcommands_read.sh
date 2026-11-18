#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_subcommands_read.sh <OMGMT_PATH> <KEY>
# Output:
#   subcommand: Description (one per line)
#
# Example:
#   cmd_subcommands_read.sh /path/to/my_oreol_mgmt NEW
#   playbook:    Adds a new playbook

OMGMT_PATH="$1"
KEY="$2"

# shellcheck source=/dev/null
source "$OMGMT_PATH/src/cmd_spec.sh"

# gather variable names that start with "${KEY}_"
while IFS= read -r v; do
  if [[ "$v" =~ ^${KEY}_(.+)_DESCRIPTION$ ]]; then
    suffix="${BASH_REMATCH[1]}"
    name="$(printf '%s' "$suffix" | tr '[:upper:]' '[:lower:]')"
    # indirect expansion to fetch the description value
    desc="${!v}"
    [[ -n "$desc" ]] || continue
    printf "%-12s %s\n" "${name}:" "$desc"
  fi
done < <(compgen -v "${KEY}_" | sort)

exit 0
