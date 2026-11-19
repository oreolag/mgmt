#!/bin/bash
set -euo pipefail

# example: omgmt update --main

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMGMT_PATH="${OMGMT_PATH:-$(dirname "$SCRIPT_DIR")}"
repo_url="https://github.com/oreolag/mgmt.git"
software_dir="$HOME/.local/share/omgmt/software"

ref=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--main) ref=main ;;
    -h|--help) exec "$OMGMT_PATH/omgmt.sh" update --help ;;
    *) printf 'Unknown flag: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

if [[ ! "$OMGMT_PATH" -ef "$software_dir" ]]; then
  echo "Run update from the installed omgmt command." >&2
  exit 1
fi

if [[ -z "$ref" ]]; then
  if ! gh_path="$(command -v gh)"; then
    echo "Missing tool: gh" >&2
    exit 1
  fi
  logged_in="$(bash "$OMGMT_PATH/src/gh_auth_status.sh" "$gh_path")"
  if [[ "$logged_in" == "0" ]]; then
    echo "Login failed: use gh auth login" >&2
    exit 1
  fi
  ref="$("$gh_path" release view --repo oreolag/mgmt --json tagName --jq .tagName)"
  if [[ -z "$ref" ]]; then
    echo "Release not found: oreolag/mgmt" >&2
    exit 1
  fi
fi

# Stage the update next to the installed software.
install_dir="$(dirname "$software_dir")"
staging="$(mktemp -d "$install_dir/.update.XXXXXXXX")"
previous="$staging/previous"
cleanup() {
  if [[ -d "$previous" && ! -e "$software_dir" ]]; then
    mv "$previous" "$software_dir" || return
  fi
  rm -rf -- "$staging"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

checkout="$staging/checkout"
snapshot="$staging/software"
git clone --branch "$ref" --recursive "$repo_url" "$checkout"

# The release metadata commit on main is newer than the tagged commit.
# Use the published release date for a release and the commit date for main.
if [[ "$ref" == main ]]; then
  version=main
  release_date="$(git -C "$checkout" log -1 --format=%cs)"
else
  version="${ref#v}"
  published_at="$("$gh_path" release view "$ref" --repo oreolag/mgmt --json publishedAt --jq .publishedAt)"
  release_date="${published_at%%T*}"
fi
printf '%s\n' "$version" > "$checkout/VERSION"
printf '%s\n' "$release_date" > "$checkout/RELEASE_DATE"

# Build the same software and cluster template archives as install.sh.
COPYFILE_DISABLE=1 tar -chf "$checkout/templates/cluster.tar" -C "$checkout" \
  --exclude='.DS_Store' hosts group_vars cmdb
mkdir "$snapshot"
COPYFILE_DISABLE=1 tar -cf - -C "$checkout" --exclude='.git' --exclude='.DS_Store' \
  --exclude='./hosts' --exclude='./group_vars' --exclude='./cmdb' . |
  tar -xf - -C "$snapshot"

# Refresh the collection in the staged snapshot before replacing the installation.
"$snapshot/collections-update.sh"
cp "$snapshot/ansible-play-completion.bash" "$staging/ansible-play-completion.bash"

# Serialize the directory swap and restore the previous snapshot if it fails.
lock="$install_dir/.update-lock"
if ! mkdir "$lock"; then
  echo "Another omgmt update is replacing the installation." >&2
  exit 1
fi
trap 'cleanup; rmdir "$lock"' EXIT
mv "$software_dir" "$previous"
mv "$snapshot" "$software_dir"
mv -f "$staging/ansible-play-completion.bash" "$install_dir/ansible-play-completion.bash"
printf '✓ omgmt updated: %s\n' "$ref"

# author: https://github.com/jmoya82
