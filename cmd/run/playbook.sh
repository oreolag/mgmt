#!/bin/bash
set -euo pipefail

# example: omgmt run playbook --cluster prova --name hello_world

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
software="${OMGMT_PATH:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
workspace="${OMGMT_CLUSTER_PATH:-$HOME/my_oreol_mgmt}"

# parse flags
cluster=""
name=""
hosts="local"
vars=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster|--name|-n|--hosts|--vars|-v)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        printf 'Missing value for %s\n' "$1" >&2
        exit 1
      fi
      case "$1" in
        --cluster) cluster="$2" ;;
        --name|-n) name="$2" ;;
        --hosts) hosts="$2" ;;
        --vars|-v) vars="$2" ;;
      esac
      shift 2
      ;;
    *)
      printf 'Unknown flag: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$name" ]]; then
  echo 'Missing option: --name <name>' >&2
  exit 1
fi
if [[ ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  printf 'Invalid playbook name: %s\n' "$name" >&2
  exit 1
fi

# select the cluster inventory
if [[ -d "$workspace" ]]; then
  workspace="$(cd "$workspace" && pwd)"
fi
if [[ -z "$cluster" ]]; then
  clusters=()
  for directory in "$workspace"/clusters/*; do
    [[ -d "$directory" ]] || continue
    candidate="${directory##*/}"
    [[ "$candidate" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]] || continue
    clusters+=("$candidate")
  done
  case "${#clusters[@]}" in
    0) echo 'Missing cluster: use omgmt new cluster --name <name>' >&2; exit 1 ;;
    1) cluster="${clusters[0]}" ;;
    *) echo 'Missing option: --cluster <name>' >&2; exit 1 ;;
  esac
fi
if [[ ! "$cluster" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ || ! -d "$workspace/clusters/$cluster" ]]; then
  printf 'Cluster not found: %s\n' "$cluster" >&2
  exit 1
fi
inventory="$workspace/clusters/$cluster/hosts"
if [[ ! -f "$inventory" ]]; then
  printf 'Missing file: %s\n' "$inventory" >&2
  exit 1
fi

# check if the playbook exists
playbook="$workspace/playbooks/$name.yml"
if [[ ! -f "$playbook" ]]; then
  playbook="$workspace/playbooks/$name.yaml"
fi
if [[ ! -f "$playbook" ]]; then
  printf 'Playbook does not exist: %s\n' "$name" >&2
  exit 1
fi

# run the playbook on the selected hosts
export ANSIBLE_ROLES_PATH="$workspace/roles:${ANSIBLE_ROLES_PATH:-$software/roles:$HOME/.ansible/roles:/usr/share/ansible/roles:/etc/ansible/roles}"
args=(--inventory "$inventory")
if [[ -n "$vars" ]]; then
  args+=(--extra-vars "$vars")
fi
exec "$software/ansible-play.sh" "$playbook" "$hosts" "${args[@]}"
