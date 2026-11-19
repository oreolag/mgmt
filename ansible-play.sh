#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <playbook> <hosts> [flags] [ansible options...]"
    echo "Playbook may be a local name in playbooks/, a collection name, or an existing file path."
    echo "Example: $0 passwordless_sudo_groupadd spark update --ask-become-pass"
    echo "Use -i or --inventory to replace the default hosts inventory."
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
# Resolve files relative to the caller before switching to cluster_dir.
if [[ -f $1 ]]; then
    playbook="$(cd -- "$(dirname -- "$1")" && pwd)/$(basename -- "$1")"
elif [[ $1 == */* ]]; then
    echo "Playbook file not found: $1" >&2
    exit 1
else
    playbook="${1##*/}"
    playbook="${playbook%.yml}"
    playbook="${playbook%.yaml}"
    playbook="${playbook//-/_}"
    if [[ -f "$cluster_dir/playbooks/$playbook.yml" ]]; then
        playbook="$cluster_dir/playbooks/$playbook.yml"
    elif [[ -f "$cluster_dir/playbooks/$playbook.yaml" ]]; then
        playbook="$cluster_dir/playbooks/$playbook.yaml"
    else
        if [[ $playbook != oreol.mgmt.* ]]; then
            playbook="oreol.mgmt.$playbook"
        fi
        if [[ ! $playbook =~ ^oreol\.mgmt\.[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            echo "Invalid collection playbook name: $playbook" >&2
            exit 1
        fi
    fi
fi
target=$2
shift 2

# Encode the target as a JSON string, keeping it a single variable value.
target_json=${target//\\/\\\\}
target_json=${target_json//\"/\\\"}
target_json=${target_json//$'\n'/\\n}
target_json=${target_json//$'\r'/\\r}
target_json=${target_json//$'\t'/\\t}
args=(--limit "$target"
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

# Additional parameters for special playbooks. Extend this conditional as needed.
playbook_name="${playbook##*/}"
playbook_name="${playbook_name%.yml}"
playbook_name="${playbook_name%.yaml}"
playbook_name="${playbook_name#oreol.mgmt.}"
if [[ $playbook_name == tailscale_install ]]; then
    # Respect an explicitly supplied Vault password source.
    vault_option=false
    for option in "$@"; do
        case "$option" in
            -J|--ask-vault-pass|--ask-vault-password|--vault-password-file|--vault-password-file=*|--vault-pass-file|--vault-pass-file=*|--vault-id|--vault-id=*)
                vault_option=true ;;
        esac
    done
    if [[ $vault_option == false && -z ${ANSIBLE_VAULT_PASSWORD_FILE:-} ]]; then
        args+=(--ask-vault-pass)
    fi
fi

# Explicit inventories replace the default; forward their arguments unchanged.
explicit_inventory=false
for option in "$@"; do
    case "$option" in
        -i*|--inventory|--inventory=*|--inventory-file|--inventory-file=*)
            explicit_inventory=true
            break
            ;;
        --) break ;;
    esac
done
if [[ $explicit_inventory == false ]]; then
    args=(--inventory "$cluster_dir/hosts" "${args[@]}")
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ansible-playbook is missing from PATH. On macOS: brew install ansible" >&2
    exit 1
fi
cd "$cluster_dir"
export ANSIBLE_CONFIG="$cluster_dir/ansible.cfg"
# Trust new SSH host keys automatically; still reject changed keys.
# Keep inventory ssh_common_args (such as ProxyJump) separate and intact.
export ANSIBLE_SSH_ARGS="${ANSIBLE_SSH_ARGS:--C -o ControlMaster=auto -o ControlPersist=60s} -o StrictHostKeyChecking=accept-new"
printf 'Running %s on %s\n' "$playbook" "$target"
exec ansible-playbook "$playbook" "${args[@]}" "$@"
