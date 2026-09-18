#!/bin/bash
set -euo pipefail

cluster_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v ansible-galaxy >/dev/null 2>&1; then
    echo "ansible-galaxy is missing from PATH. Install Ansible before updating collections." >&2
    exit 1
fi

cd "$cluster_dir"
export ANSIBLE_CONFIG="$cluster_dir/ansible.cfg"
exec ansible-galaxy collection install -r requirements.yml -p ./collections --force
