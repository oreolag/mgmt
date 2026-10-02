#!/bin/bash
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    echo "Usage: $0 <playbook_name>"
    echo "Deletes the local playbook and its matching role directory."
    exit 0
fi
if [[ $# -ne 1 || ! $1 =~ ^[a-z][a-z0-9_]*$ || $1 == cli_install ]]; then
    echo "Invalid playbook: ${*:-<empty>}" >&2
    exit 1
fi

cluster_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
name=$1

# Do not traverse symlinked parent directories outside this project.
for directory in "$cluster_dir/playbooks" "$cluster_dir/roles"; do
    if [[ -L $directory ]]; then
        echo "Playbook cannot be deleted: $name" >&2
        exit 1
    fi
done

found=false
for target in "$cluster_dir/playbooks/$name.yml" "$cluster_dir/playbooks/$name.yaml" "$cluster_dir/roles/$name"; do
    if [[ -e $target || -L $target ]]; then
        found=true
    fi
done
if [[ $found == false ]]; then
    echo "Playbook does not exist: $name" >&2
    exit 1
fi

rm -rf -- "$cluster_dir/playbooks/$name.yml" "$cluster_dir/playbooks/$name.yaml" "$cluster_dir/roles/$name"
