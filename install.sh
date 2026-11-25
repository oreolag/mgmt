#!/usr/bin/env bash

set -euo pipefail

# inputs
installation_type="${1:-admin_local_repo}"
launch_directory="$(pwd -P)"

# format
bold=$(tput bold 2>/dev/null || true)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

# constants
COLOR_PASSED=$(printf '\033[38;2;96;186;66m')
REPO_URL="https://github.com/oreolag/mgmt.git"
TMP_PATH="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_PATH"
}

trap cleanup EXIT

# root check
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root:"
    echo "curl -fsSL https://raw.githubusercontent.com/oreolag/mgmt/main/install.sh | sudo bash"
    exit 1
fi

# platform check
platform="$(uname -s)"
if [[ "$platform" = "Darwin" ]]; then
    if [[ "$installation_type" = "odev_plugin" ]]; then
        echo "Error: mgmt (odev_plugin) requires Ubuntu"
        exit 1
    fi
    # sudo may omit Homebrew from PATH on Apple Silicon and Intel Macs.
    export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
    if ! command -v brew >/dev/null 2>&1; then
        echo "Please install homebrew"
        exit 1
    fi
elif [[ -f /etc/os-release ]]; then
    . /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        echo "Error: mgmt requires Ubuntu"
        exit 1
    fi
else
    echo "Error: cannot determine operating system"
    exit 1
fi

if [[ "$installation_type" == "admin_local_repo" ]]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "Missing tool: gh" >&2
        exit 1
    fi
    if [[ -z "${SUDO_USER:-}" || "$SUDO_USER" == root ]]; then
        echo "Run the installer with sudo from your regular user account." >&2
        exit 1
    fi
    gh_path="$(command -v gh)"

fi

echo "${bold}[INFO] Installing prerequisites...${normal}"

if [[ "$platform" = "Darwin" ]]; then
    if ! command -v git >/dev/null 2>&1 \
        || ! command -v ansible-playbook >/dev/null 2>&1 \
        || ! command -v ansible-galaxy >/dev/null 2>&1 \
        || ! command -v gh >/dev/null 2>&1; then
        sudo -H -u "$SUDO_USER" "$(command -v brew)" install git ansible gh
    fi
else
    apt-get update

    apt-get install -y \
        git \
        ansible \
        python3 \
        python3-pip \
        gh \
        sudo
fi

echo ""
echo "${bold}[INFO] Cloning mgmt repository...${normal}"

# Show download progress and fail if a transfer stalls for a full minute.
git -c http.lowSpeedLimit=1 -c http.lowSpeedTime=60 \
    clone --branch main --recursive --progress "$REPO_URL" "$TMP_PATH/mgmt"

cd "$TMP_PATH/mgmt"

echo ""

if [ "$installation_type" = "admin_local_repo" ]; then
    echo "${bold}[INFO] Installing omgmt software...${normal}"
    # Bundle the starter files for omgmt create cluster.
    COPYFILE_DISABLE=1 tar -chf templates/cluster.tar --exclude='.DS_Store' hosts group_vars cmdb
    COPYFILE_DISABLE=1 tar -cf "$TMP_PATH/software.tar" --exclude='.git' --exclude='.DS_Store' \
        --exclude='./hosts' --exclude='./group_vars' --exclude='./cmdb' .
    export MGMT_SOFTWARE_ARCHIVE="$TMP_PATH/software.tar"
    export MGMT_ANSIBLE_GALAXY="$(command -v ansible-galaxy)"
    ansible-playbook -i localhost, -c local install.yml --extra-vars "admin_local_repo=true"

    echo ""
    echo "${bold}[INFO] Setting up my_oreol_mgmt...${normal}"
    # Leave the private temporary directory before starting a shell as the user.
    cd /
    logged_in="$(sudo -H -u "$SUDO_USER" /bin/bash -c '
        cd "$HOME" || exit 1
        exec /bin/bash -c "$1" gh-auth-status "$2"
    ' bash "$(cat "$TMP_PATH/mgmt/src/gh_auth_status.sh")" "$gh_path")"
    if [[ "$logged_in" == "0" ]]; then
        echo "Login failed: use gh auth login" >&2
        exit 1
    fi

    github_account="$(sudo -H -u "$SUDO_USER" /bin/bash -c '
        cd "$HOME" || exit 1
        GH_PROMPT_DISABLED=1 exec "$1" api --hostname github.com user </dev/null
    ' bash "$gh_path")" || exit 1
    github_user="$(python3 -c 'import json, sys; print(json.load(sys.stdin)["login"])' <<< "$github_account")" || exit 1
    [[ -n "$github_user" ]] || exit 1
    workspace="${launch_directory%/}/my_oreol_mgmt"

    sudo -H -u "$SUDO_USER" /bin/bash -c '
        cd "$HOME" || exit 1
        set -e
        /bin/bash -c "$1" admin-repo-install "${@:2}"
        if [[ ! -d "$2/.git" && ! -f "$2/.git" ]]; then
            printf "Missing cluster repository: %s\n" "$2" >&2
            exit 1
        fi
        config_dir="$HOME/.config/omgmt"
        mkdir -p "$config_dir"
        config_tmp="$(mktemp "$config_dir/workspace.XXXXXXXX")"
        trap '\''rm -f "$config_tmp"'\'' EXIT
        printf "%s\n" "$2" > "$config_tmp"
        mv -f "$config_tmp" "$config_dir/workspace"
    ' bash "$(cat "$TMP_PATH/mgmt/src/admin-repo-install.sh")" \
        "$workspace" "$github_user" "$gh_path" </dev/null
    printf 'Workspace: %s\n' "$workspace"
elif [ "$installation_type" = "odev_plugin" ]; then
    # Reuse the recursive checkout instead of downloading it again in Ansible.
    COPYFILE_DISABLE=1 tar -cf "$TMP_PATH/software.tar" --exclude='.git' --exclude='.DS_Store' .
    export MGMT_SOFTWARE_ARCHIVE="$TMP_PATH/software.tar"
    echo "${bold}[INFO] Running installer...${normal}"
    ansible-playbook \
    -i localhost, \
    -c local \
    install.yml \
    --extra-vars "odev_plugin=true" #--check
else
    echo "Unknown installation mode: $installation_type" >&2
    exit 1
fi

echo "${bold}${COLOR_PASSED}✓${normal} mgmt installation completed${normal}"
