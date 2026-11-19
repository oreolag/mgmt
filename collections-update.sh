#!/bin/bash
set -euo pipefail

cluster_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

galaxy="${MGMT_ANSIBLE_GALAXY:-ansible-galaxy}"
if ! command -v "$galaxy" >/dev/null 2>&1; then
    echo "ansible-galaxy is missing from PATH. Install Ansible before updating collections." >&2
    exit 1
fi

cd "$cluster_dir"
export ANSIBLE_CONFIG="$cluster_dir/ansible.cfg"
exec "$galaxy" collection install -r requirements.yml -p ./collections --force
