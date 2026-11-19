#!/usr/bin/env bash
set -euo pipefail

# format
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

print_help() {
  echo "Commit selected changes and push the current branch."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_push.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --cluster   Cluster name"
  echo "    --playbook  Playbook and matching role"
  echo "    --comment   Commit subject"
  echo "    -h, --help  Show this help"
}

msg=""

# parse flags
cluster=""
playbook=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster|-c|--playbook|-p|--comment)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        echo "Missing value for $1" >&2
        exit 1
      fi
      case "$1" in
        --cluster|-c) cluster="$2" ;;
        --playbook|-p) playbook="$2" ;;
        --comment) msg="$2" ;;
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

# commit only the selected changes
if [[ ${#targets[@]} -gt 0 ]]; then
  existing_targets=()
  for target in "${targets[@]}"; do
    if [[ -e "$target" || -L "$target" ]] ||
       [[ -n "$(git ls-files -- "$target")" ]] ||
       git cat-file -e "HEAD:$target" 2>/dev/null; then
      existing_targets+=("$target")
    fi
  done
  if [[ ${#existing_targets[@]} -eq 0 ]]; then
    echo "Path not found: ${targets[0]}" >&2
    exit 1
  fi
  if [[ -n "$(git status --porcelain -- "${existing_targets[@]}")" ]]; then
    if [[ -z "$msg" ]]; then
      printf "comment: " > /dev/tty
      read -r msg < /dev/tty
    fi
    git add -A -- "${existing_targets[@]}"
    git commit --only -m "$msg" -- "${existing_targets[@]}"
  fi
fi

# also push existing commits when no path is selected
github_git push -u origin "HEAD:refs/heads/$branch"
