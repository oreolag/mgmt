#!/usr/bin/env bash
set -euo pipefail

# format
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

print_help() {
  echo "Show local changes in the management repository."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  git_diff.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --cluster   Cluster name"
  echo "    --playbook  Playbook and matching role"
  echo "    -h, --help  Show this help"
}

# parse flags
cluster=""
playbook=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster|-c|--playbook|-p)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "Missing value for $1" >&2
        exit 1
      fi
      case "$1" in
        --cluster|-c) cluster="$2" ;;
        --playbook|-p) playbook="$2" ;;
      esac
      shift 2
      ;;
    --help|-h) print_help; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ensure we are inside the management repository
if [[ ! -e .git ]]; then
  echo "Error: not inside a git repository" >&2
  exit 1
fi

# select the paths to manage
targets=()
if [[ -n "$cluster" && -n "$playbook" ]]; then
  echo "Specify exactly one of --cluster or --playbook with a name" >&2
  exit 1
elif [[ -n "$cluster" ]]; then
  if [[ ! "$cluster" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
    echo "Invalid cluster name: $cluster" >&2
    exit 1
  fi
  targets=("clusters/$cluster")
elif [[ -n "$playbook" ]]; then
  if [[ ! "$playbook" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
    echo "Invalid playbook name: $playbook" >&2
    exit 1
  fi
  targets=("playbooks/$playbook.yml" "playbooks/$playbook.yaml" "roles/$playbook")
fi

# staged and unstaged changes compared with the last commit
git --no-pager diff HEAD -- ${targets[@]+"${targets[@]}"}

# show new files without staging them
while IFS= read -r -d '' new_file; do
  git --no-pager diff --no-index -- /dev/null "$new_file" || {
    status=$?
    [[ "$status" == "1" ]] || exit "$status"
  }
done < <(git ls-files --others --exclude-standard -z -- ${targets[@]+"${targets[@]}"})
