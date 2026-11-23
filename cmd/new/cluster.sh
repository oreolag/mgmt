#!/bin/bash
set -euo pipefail

# example: omgmt new cluster --name test

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

destinations=("clusters/$name")
commit_paths=("${destinations[@]}")

if [[ ! -e "$workspace/.git" ]]; then
  python3 "$software/src/odev_messages.py" --error invalid_git_repository -- "$workspace"
  exit 1
fi

# Check if the name exists locally before contacting GitHub.
for destination in "${destinations[@]}"; do
  if [[ -e "$workspace/$destination" || -L "$workspace/$destination" ]]; then
    printf 'Cluster already exists: %s\n' "$name" >&2
    exit 1
  fi
done

# Check GitHub CLI and get the signed-in user.
if ! gh_path="$(command -v gh)"; then
  python3 "$software/src/odev_messages.py" --error missing_tool -- gh
  exit 1
fi
# check on GitHub CLI
auth_status_script="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/src/gh_auth_status.sh"
logged_in="$(bash "$auth_status_script" "$gh_path")"
if [[ "$logged_in" == "0" ]]; then
  python3 "$software/src/odev_messages.py" --error login_failed -- gh
  exit 1
fi

# get GitHub user
github_account="$(GH_PROMPT_DISABLED=1 "$gh_path" api --hostname github.com user)" || exit 1
github_user="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["login"])' <<< "$github_account")" || exit 1
[[ -n "$github_user" ]] || exit 1

cd "$workspace"
workspace="$(pwd -P)"
if ! branch="$(git symbolic-ref --quiet --short HEAD)"; then
  echo "Switch to a branch before creating a cluster" >&2
  exit 1
fi

github_git() {
  git -c credential.helper= \
    -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" "$@"
}

# Check the current remote branch before creating files.
github_git fetch --no-tags origin "refs/heads/$branch"
remote_head="$(git rev-parse --verify FETCH_HEAD)"
for destination in "${destinations[@]}"; do
  if git cat-file -e "$remote_head:$destination" 2>/dev/null; then
    printf 'Cluster already exists: %s\n' "$name" >&2
    exit 1
  fi
done

# A push of the new commit must not publish unrelated local commits.
if [[ "$(git rev-parse HEAD)" != "$remote_head" ]]; then
  printf 'Branch is out of sync: %s. Sync with origin before creating a cluster.\n' "$branch" >&2
  exit 1
fi

# copy cluster templates
cluster_dir="$workspace/clusters/$name"
mkdir -p "$workspace/clusters"
# Prepare the starter files before reserving the cluster name.
staging="$(mktemp -d "$workspace/clusters/.omgmt-cluster.XXXXXXXX")"
trap 'rm -rf -- "$staging"' EXIT
if [[ -f "$software/templates/cluster.tar" ]]; then
  tar -xf "$software/templates/cluster.tar" -C "$staging"
else
  # A source checkout has the starter files in the repository root.
  COPYFILE_DISABLE=1 tar -chf - -C "$software" --exclude='.DS_Store' hosts group_vars cmdb |
    tar -xf - -C "$staging"
fi

mkdir "$cluster_dir"
mv "$staging/hosts" "$staging/group_vars" "$staging/cmdb" "$cluster_dir/"

# Configure Git identity if missing, then commit and push only the new files.
if [[ -z "$(git config user.name || true)" ]]; then
  git config user.name "$github_user"
fi
if [[ -z "$(git config user.email || true)" ]]; then
  git config user.email "$github_user@users.noreply.github.com"
fi
git add -- "${commit_paths[@]}"
git commit --only -m "Add cluster $name" -- "${commit_paths[@]}"
if ! github_git push origin "HEAD:refs/heads/$branch"; then
  printf 'Push failed: %s was committed locally. Sync with origin and retry the push.\n' "$name" >&2
  exit 1
fi
printf 'Cluster created: %s\n' "$name"
