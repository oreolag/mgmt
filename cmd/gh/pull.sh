#!/bin/bash
set -euo pipefail

# example: omgmt gh pull

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMGMT_PATH="${OMGMT_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
repository_path="${OMGMT_CLUSTER_PATH:-$HOME/my_oreol_mgmt}"

# use the management repository's helper
cd "$repository_path" || exit 1
exec bash "$OMGMT_PATH/src/github_pull.sh" "$@"

# author: https://github.com/jmoya82
