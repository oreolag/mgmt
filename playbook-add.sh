#!/bin/bash
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    echo "Usage: $0 <playbook_name>"
    exit 0
fi
if [[ $# -ne 1 || ! $1 =~ ^[a-z][a-z0-9_]*$ || $1 == cli_install ]]; then
    echo "Invalid playbook: ${*:-<empty>}" >&2
    exit 1
fi

cluster_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
name=$1
playbook="$cluster_dir/playbooks/$name.yml"
role="$cluster_dir/roles/$name"

for destination in "$playbook" "$cluster_dir/playbooks/$name.yaml" "$role"; do
    if [[ -e $destination || -L $destination ]]; then
        if [[ $destination == "$role" ]]; then
            echo "Role already exists: $name" >&2
        else
            echo "Playbook already exists: $name" >&2
        fi
        exit 1
    fi
done

for template in MY_PLAYBOOK.yml MY_PLAYBOOK_role/README.md MY_PLAYBOOK_role/tasks/main.yml; do
    if [[ ! -r "$cluster_dir/templates/$template" ]]; then
        echo "Template does not exist: $template" >&2
        exit 1
    fi
done

mkdir -p "$cluster_dir/playbooks" "$role/tasks"
sed "s/MY_PLAYBOOK/$name/g" "$cluster_dir/templates/MY_PLAYBOOK.yml" > "$playbook"
sed "s/MY_PLAYBOOK/$name/g" "$cluster_dir/templates/MY_PLAYBOOK_role/README.md" > "$role/README.md"
sed "s/MY_PLAYBOOK/$name/g" "$cluster_dir/templates/MY_PLAYBOOK_role/tasks/main.yml" > "$role/tasks/main.yml"
