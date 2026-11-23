#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -gt 0 ]]; then
  python3 "$SCRIPT_DIR/../../src/odev_messages.py" --error unknown_flag -- "$1"
  exit 1
fi

exec "$SCRIPT_DIR/../../collections-update.sh"
