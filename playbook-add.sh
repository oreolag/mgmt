#!/bin/bash
set -euo pipefail

if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    echo "Usage: $0 <playbook_name>"
    exit 0
fi
if [[ $# -ne 1 || ! $1 =~ ^[a-z][a-z0-9_]*$ || $1 == cli_install ]]; then
    echo "Provide a lowercase playbook name using letters, digits, and underscores (for example: set_ip)." >&2
    echo "The name cli_install is reserved." >&2
    exit 1
fi

cluster_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
name=$1
playbook="$cluster_dir/playbooks/$name.yml"
role="$cluster_dir/roles/$name"

for destination in "$playbook" "$cluster_dir/playbooks/$name.yaml" "$role"; do
    if [[ -e $destination || -L $destination ]]; then
        echo "Already exists: $destination. No files were changed." >&2
        exit 1
    fi
done

for template in MY_PLAYBOOK.yml MY_PLAYBOOK_role/README.md MY_PLAYBOOK_role/tasks/main.yml; do
    if [[ ! -r "$cluster_dir/templates/$template" ]]; then
        echo "Missing template: $template" >&2
        exit 1
    fi
done

mkdir -p "$cluster_dir/playbooks" "$role/tasks"
sed "s/MY_PLAYBOOK/$name/g" "$cluster_dir/templates/MY_PLAYBOOK.yml" > "$playbook"
sed "s/MY_PLAYBOOK/$name/g" "$cluster_dir/templates/MY_PLAYBOOK_role/README.md" > "$role/README.md"
sed "s/MY_PLAYBOOK/$name/g" "$cluster_dir/templates/MY_PLAYBOOK_role/tasks/main.yml" > "$role/tasks/main.yml"

echo "Created playbooks/$name.yml and roles/$name."
echo "Run from $cluster_dir: ./ansible-play.sh $name local"
