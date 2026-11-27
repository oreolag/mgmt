#!/bin/bash
set -euo pipefail

# example: omgmt run playbook --cluster prova --name hello_world

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

# validate supplied values before prompting, then validate each answer
name="-"
cluster="-"
hosts="local"
vars="-"
for field in "" ${mandatory_flags//,/ }; do
  parsed_flags="$("$software/src/cmd_prompt.sh" --required "$mandatory_flags" \
    --field "$field" --params ${flags[@]+"${flags[@]}"} -- "$parsed_flags")" || exit 1
  while IFS='=' read -r key value; do
    case "$key" in
      cluster) cluster="$value" ;;
      name) name="$value" ;;
      hosts) hosts="$value" ;;
      vars) vars="$value" ;;
    esac
  done <<< "$parsed_flags"

  if [[ "$name" != "-" && ! "${name#oreol.mgmt.}" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
    python3 "$software/src/odev_messages.py" --error invalid_playbook_name -- "$name"
    exit 1
  fi
done

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

# run the playbook on the selected hosts
export ANSIBLE_ROLES_PATH="$workspace/roles:${ANSIBLE_ROLES_PATH:-$software/roles:$HOME/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles}"
args=(--inventory "$inventory")
if [[ "$vars" != "-" ]]; then
  if [[ "$vars" == %* ]]; then
    vars="${vars#%}"
    vars="${vars//%0A/$'\n'}"
    vars="${vars//%25/%}"
  fi
  args+=(--extra-vars "$vars")
fi
# Resolve the development installer directly, before collection lookup.
if [[ "${name#oreol.mgmt.}" == "odev_install_local" ]]; then
  cli_local_path="$(python3 "$software/src/cli_local_path_read.py" \
    "$inventory" "$hosts" "$software/ansible.cfg" "${args[@]}")" || exit 1

  if [[ "$cli_local_path" != /* ]]; then
    python3 "$software/src/odev_messages.py" --error invalid_value -- \
      cli.local_path "$cli_local_path" "an absolute local checkout path"
    exit 1
  fi

  playbook="$cli_local_path/install.yml"
  if [[ ! -f "$playbook" ]]; then
    python3 "$software/src/odev_messages.py" --error file_not_found -- "$playbook"
    exit 1
  fi

  cli_vars="$(python3 -c \
    'import json, sys; print(json.dumps({"cli": {"local_path": sys.argv[1]}}))' \
    "$cli_local_path")"
  args+=(--extra-vars "$cli_vars")
else
  # check if the playbook exists
  playbook="$workspace/playbooks/$name.yml"
  if [[ ! -f "$playbook" ]]; then
    playbook="$workspace/playbooks/$name.yaml"
  fi
  if [[ "$name" == oreol.mgmt.* || ! -f "$playbook" ]]; then
    collection_name="${name#oreol.mgmt.}"
    collection_name="${collection_name//-/_}"
    collection_playbook="$software/collections/ansible_collections/oreol/mgmt/playbooks/$collection_name"
    if [[ ! -f "$collection_playbook.yml" && ! -f "$collection_playbook.yaml" ]]; then
      python3 "$software/src/odev_messages.py" --error playbook_not_found -- "$name"
      exit 1
    fi
    playbook="oreol.mgmt.$collection_name"
  fi
fi

exec "$software/ansible-play.sh" "$playbook" "$hosts" "${args[@]}"
