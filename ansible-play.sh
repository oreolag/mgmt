#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <playbook> <hosts> [flags] [ansible options...]"
    echo "Example: $0 passwordless_sudo_groupadd spark update --ask-become-pass"
    echo "Flags are comma-separated variable names set to true (e.g. update,validate)."
}
if [[ ${1:-} == --help || ${1:-} == -h ]]; then
    usage
    exit 0
fi
if [[ $# -lt 2 || -z ${2:-} ]]; then
    usage >&2
    exit 1
fi

cluster_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
playbook="${1##*/}"
playbook="${playbook%.yml}"
playbook="${playbook%.yaml}"
playbook="${playbook//-/_}"
if [[ $playbook != oreol.mgmt.* ]]; then
    playbook="oreol.mgmt.$playbook"
fi
if [[ ! $playbook =~ ^oreol\.mgmt\.[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
    echo "Invalid collection playbook name: $playbook" >&2
    exit 1
fi
target=$2
shift 2

# Encode the target as a JSON string, keeping it a single variable value.
target_json=${target//\\/\\\\}
target_json=${target_json//\"/\\\"}
target_json=${target_json//$'\n'/\\n}
target_json=${target_json//$'\r'/\\r}
target_json=${target_json//$'\t'/\\t}
args=(--inventory "$cluster_dir/hosts" --limit "$target"
      --extra-vars "{\"oreol_target\":\"$target_json\"}")

if [[ $# -gt 0 && $1 != -* ]]; then
    flags=$1
    shift
    IFS=',' read -r -a flag_names <<< "$flags"
    for flag in "${flag_names[@]}"; do
        if [[ ! $flag =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ || $flag == oreol_target ]]; then
            echo "Invalid flag: $flag. Use names such as update,validate." >&2
            exit 1
        fi
        args+=(--extra-vars "{\"$flag\":true}")
    done
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ansible-playbook is missing from PATH. On macOS: brew install ansible" >&2
    exit 1
fi
cd "$cluster_dir"
export ANSIBLE_CONFIG="$cluster_dir/ansible.cfg"
printf 'Running %s on %s\n' "$playbook" "$target"
exec ansible-playbook "$playbook" "${args[@]}" "$@"
