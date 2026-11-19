#!/bin/bash
set -euo pipefail

# example: omgmt delete cluster --name test

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
software="${OMGMT_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
workspace="${OMGMT_CLUSTER_PATH:-$HOME/my_oreol_mgmt}"

# read command description, flags, and mandatory fields
COMMAND="$(basename "$SCRIPT_DIR")"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"
command_description="$("$software/src/cmd_description_read.sh" "$software" "$KEY")"
flag_specs="$("$software/src/cmd_flags_read.sh" "$software" "$KEY")"
mandatory_flags="$("$software/src/cmd_mandatory_flags_read.sh" "$software" "$KEY")"
flags=()
while IFS= read -r flag; do
  [[ -n "$flag" ]] && flags+=("$flag")
done <<< "$flag_specs"

# (maybe) print help
"$software/src/cmd_help_print.sh" --maybe \
  omgmt "$COMMAND" "$SUBCOMMAND" "$command_description" \
  0 0 0 ${flags[@]+"${flags[@]}"} -- "$@" && exit 0

# parse flags
parsed_flags="$("$software/src/cmd_parse.sh" --params ${flags[@]+"${flags[@]}"} -- "$@")" || exit 1

# validate supplied values before prompting, then validate each answer
name="-"
for field in "" ${mandatory_flags//,/ }; do
  parsed_flags="$("$software/src/cmd_prompt.sh" --required "$mandatory_flags" \
    --field "$field" --params ${flags[@]+"${flags[@]}"} -- "$parsed_flags")" || exit 1
  while IFS='=' read -r key value; do
    if [[ "$key" == name ]]; then
      name="$value"
    fi
  done <<< "$parsed_flags"

  if [[ "$name" != "-" && ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
    printf 'Invalid cluster name: %s\n' "$name" >&2
    exit 1
  fi
done

targets=("clusters/$name")

if [[ ! -e "$workspace/.git" ]]; then
  printf 'Missing cluster repository: %s\n' "$workspace" >&2
  exit 1
fi

cd "$workspace"

# protect symlinked directories
if [[ -L clusters || -L "clusters/$name" ]]; then
  printf 'Cluster cannot be deleted: %s\n' "$name" >&2
  exit 1
fi

# check if exists
if [[ "$(git cat-file -t "HEAD:clusters/$name" 2>/dev/null || true)" != tree ]]; then
  printf 'Cluster does not exist: %s\n' "$name" >&2
  exit 1
fi

# Check GitHub CLI and get the signed-in user.
if ! gh_path="$(command -v gh)"; then
  echo "Missing tool: gh" >&2
  exit 1
fi
# check on GitHub CLI
auth_status_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/gh_auth_status.sh"
logged_in="$(bash "$auth_status_script" "$gh_path")"
if [[ "$logged_in" == "0" ]]; then
  echo "Login failed: use gh auth login" >&2
  exit 1
fi

# get GitHub user
github_account="$(GH_PROMPT_DISABLED=1 "$gh_path" api --hostname github.com user)" || exit 1
github_user="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["login"])' <<< "$github_account")" || exit 1
[[ -n "$github_user" ]] || exit 1

if ! branch="$(git symbolic-ref --quiet --short HEAD)"; then
  echo "Switch to a branch before deleting a cluster" >&2
  exit 1
fi

github_git() {
  git -c credential.helper= \
    -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" "$@"
}

# check on branch
github_git fetch --no-tags origin "refs/heads/$branch"
remote_head="$(git rev-parse --verify FETCH_HEAD)"
if [[ "$(git rev-parse HEAD)" != "$remote_head" ]]; then
  printf 'Branch is out of sync: %s. Sync with origin before deleting a cluster.\n' "$branch" >&2
  exit 1
fi

# confirm deletion
printf 'Delete cluster %s? [y/N] ' "$name" >&2
if ! read -r answer || [[ "$answer" != [yY] && "$answer" != [yY][eE][sS] ]]; then
  echo "Deletion cancelled."
  exit 0
fi

# protect uncommitted files in the selected paths
if [[ -n "$(git status --porcelain --untracked-files=all --ignored -- "${targets[@]}")" ]]; then
  printf 'Cluster has local changes: %s\n' "$name" >&2
  exit 1
fi

tracked_targets=()
for target in "${targets[@]}"; do
  if git cat-file -e "HEAD:$target" 2>/dev/null; then
    tracked_targets+=("$target")
  fi
done

# configure Git identity if missing
if [[ -z "$(git config user.name || true)" ]]; then
  git config user.name "$github_user"
fi
if [[ -z "$(git config user.email || true)" ]]; then
  git config user.email "$github_user@users.noreply.github.com"
fi

# delete and commit only this cluster, then push the checked branch
git rm -r -- "${tracked_targets[@]}"
git commit --only -m "Delete cluster $name" -- "${tracked_targets[@]}"
if ! github_git push origin "HEAD:refs/heads/$branch"; then
  printf 'Push failed: deletion of %s was committed locally. Sync with origin and retry the push.\n' "$name" >&2
  exit 1
fi

# print
printf 'Cluster deleted: %s\n' "$name"

# author: https://github.com/jmoya82
