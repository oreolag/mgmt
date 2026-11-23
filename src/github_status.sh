#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# format
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

print_help() {
  echo "Fetch origin and show Git status."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_status.sh"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "  This command has no flags."
}

# parse flags
case "${1:-}" in
  --help|-h) print_help; exit 0 ;;
  "") ;;
  *) python3 "$SCRIPT_DIR/odev_messages.py" --error unknown_option -- "$1"; exit 1 ;;
esac

# ensure we are inside the management repository
if [[ ! -e .git ]]; then
  python3 "$SCRIPT_DIR/odev_messages.py" --error invalid_git_repository -- "$PWD"
  exit 1
fi

# check on GitHub CLI
if ! gh_path="$(command -v gh)"; then
  python3 "$SCRIPT_DIR/odev_messages.py" --error missing_tool -- gh
  exit 1
fi
logged_in="$(bash "$SCRIPT_DIR/gh_auth_status.sh" "$gh_path")"
if [[ "$logged_in" == "0" ]]; then
  python3 "$SCRIPT_DIR/odev_messages.py" --error login_failed -- gh
  exit 1
fi

github_git() {
  git -c credential.helper= \
    -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" "$@"
}

# refresh remote-tracking branches before showing Git status
github_git fetch --quiet --no-tags origin
exec git status
