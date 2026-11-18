#!/usr/bin/env bash
set -euo pipefail

cluster_name=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name|-n)
      if [[ -z "${2:-}" || "$2" == -* ]]; then
        printf 'Missing value for %s\n' "$1" >&2
        exit 1
      fi
      cluster_name="$2"
      shift 2
      ;;
    *)
      printf 'Unknown flag: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$cluster_name" ]]; then
  echo 'Missing option: --name <name>' >&2
  exit 1
fi
if [[ ! "$cluster_name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  printf 'Invalid cluster name: %s\n' "$cluster_name" >&2
  exit 1
fi

workspace="${OMGMT_CLUSTER_PATH:-$HOME/my_oreol_mgmt}"
software="${OMGMT_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
if [[ ! -d "$workspace" ]]; then
  printf 'Missing cluster repository: %s\n' "$workspace" >&2
  exit 1
fi

cluster_dir="$workspace/clusters/$cluster_name"
mkdir -p "$workspace/clusters"
if [[ -e "$cluster_dir" || -L "$cluster_dir" ]]; then
  printf 'Cluster already exists: %s\n' "$cluster_name" >&2
  exit 1
fi

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
printf 'Cluster created: %s\n' "$cluster_name"
