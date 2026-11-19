#!/usr/bin/env bash
set -euo pipefail

# format
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

print_help() {
  echo "Push the current branch to origin."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_push.sh"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "  This command has no flags."
}

# parse flags
case "${1:-}" in
  --help|-h) print_help; exit 0 ;;
  "") ;;
  *) echo "Unknown option: $1" >&2; exit 1 ;;
esac

# ensure we are inside the management repository
if [[ ! -e .git ]]; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

# check on GitHub CLI
if ! gh_path="$(command -v gh)"; then
  echo "Missing tool: gh" >&2
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
logged_in="$(bash "$SCRIPT_DIR/gh_auth_status.sh" "$gh_path")"
if [[ "$logged_in" == "0" ]]; then
  echo "Login failed: use gh auth login" >&2
  exit 1
fi

github_git() {
  git -c credential.helper= \
    -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" "$@"
}

branch="$(git symbolic-ref --quiet --short HEAD)"

github_git push -u origin "HEAD:refs/heads/$branch"
