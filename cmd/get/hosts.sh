#!/bin/bash
set -euo pipefail

# example: omgmt get hosts --cluster prova

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

# Require an explicit choice when the workspace has multiple clusters.
if [[ -d "$workspace" ]]; then
  workspace="$(cd "$workspace" && pwd)"
fi
clusters=()
for directory in "$workspace"/clusters/*; do
  [[ -d "$directory" ]] || continue
  candidate="${directory##*/}"
  [[ "$candidate" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]] || continue
  clusters+=("$candidate")
done
if [[ -n "${clusters[1]:-}" ]]; then
  mandatory_flags="${mandatory_flags:+$mandatory_flags,}cluster"
fi

# prompt for the cluster only when multiple clusters exist
parsed_flags="$("$software/src/cmd_prompt.sh" --required "$mandatory_flags" \
  --params ${flags[@]+"${flags[@]}"} -- "$parsed_flags")" || exit 1
cluster="-"
while IFS='=' read -r key value; do
  case "$key" in
    cluster) cluster="$value" ;;
  esac
done <<< "$parsed_flags"

# Select the sole cluster when none was supplied.
if [[ "$cluster" == "-" ]]; then
  if [[ -z "${clusters[0]:-}" ]]; then
    echo 'No clusters found' >&2
    exit 1
  fi
  cluster="${clusters[0]}"
fi
if [[ ! "$cluster" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ || ! -d "$workspace/clusters/$cluster" ]]; then
  printf 'Cluster not found: %s\n' "$cluster" >&2
  exit 1
fi
inventory="$workspace/clusters/$cluster/hosts"
if [[ ! -f "$inventory" ]]; then
  python3 "$software/src/odev_messages.py" --error file_not_found -- "$inventory"
  exit 1
fi

# print the cluster inventory unchanged
cat "$inventory"
