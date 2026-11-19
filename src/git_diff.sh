#!/usr/bin/env bash
set -euo pipefail

# format
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

print_help() {
  echo "Show local changes in the management repository."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  git_diff.sh"
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

# staged and unstaged changes compared with the last commit
git --no-pager diff HEAD --

# show new files without staging them
while IFS= read -r -d '' new_file; do
  git --no-pager diff --no-index -- /dev/null "$new_file" || {
    status=$?
    [[ "$status" == "1" ]] || exit "$status"
  }
done < <(git ls-files --others --exclude-standard -z --)
