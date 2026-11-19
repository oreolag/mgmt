#!/bin/bash
set -euo pipefail

if [[ $# -gt 0 ]]; then
  printf 'Unknown flag: %s\n' "$1" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/../../collections-update.sh"
