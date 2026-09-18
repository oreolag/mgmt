#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <playbook> <hosts> [flags] [ansible options...]"
    echo "Example: $0 passwordless_sudo_groupadd spark update --ask-become-pass"
    echo "Install Oreol CLI: $0 cli_install local repo --ask-become-pass"
    echo "For cli_install, set CLI_LOCAL_PATH to your local CLI checkout first."
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
if [[ $playbook == cli_install ]]; then
    cli_path_file="$cluster_dir/CLI_LOCAL_PATH"
    if [[ ! -r $cli_path_file ]]; then
        echo "Please update CLI_LOCAL_PATH" >&2
        exit 1
    fi
    cli_local_path=$(cat -- "$cli_path_file")
    # Trim surrounding whitespace, matching the inventory's file lookup.
    cli_local_path="${cli_local_path#"${cli_local_path%%[![:space:]]*}"}"
    cli_local_path="${cli_local_path%"${cli_local_path##*[![:space:]]}"}"
    if [[ -z $cli_local_path ]]; then
        echo "Please update CLI_LOCAL_PATH" >&2
        exit 1
    fi
    if [[ $cli_local_path != /* || ! -d $cli_local_path ]]; then
        echo "Please update CLI_LOCAL_PATH" >&2
        exit 1
    fi
    playbook="$cluster_dir/cli_install.yml"
    if [[ ! -f $playbook ]]; then
        echo "CLI installer is missing. Run: git submodule update --init --recursive" >&2
        exit 1
    fi
else
    if [[ $playbook != oreol.mgmt.* ]]; then
        playbook="oreol.mgmt.$playbook"
    fi
    if [[ ! $playbook =~ ^oreol\.mgmt\.[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "Invalid collection playbook name: $playbook" >&2
        exit 1
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
