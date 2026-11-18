#!/usr/bin/env bash

set -euo pipefail

# inputs
installation_type="${1:-admin_local_repo}"
export MGMT_ADMIN_PATH="$PWD/my_oreol_mgmt"

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
    if ! github_user="$(sudo -H -u "$SUDO_USER" "$gh_path" api --hostname github.com user --jq .login 2>/dev/null)" ||
        [[ -z "$github_user" ]]; then
        echo "Login failed: use gh auth login" >&2
        exit 1
    fi
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
echo "${bold}[INFO] Running installer...${normal}"

if [ "$installation_type" = "admin_local_repo" ]; then
    (
        cd "$(dirname "$MGMT_ADMIN_PATH")"
        sudo -H -u "$SUDO_USER" bash -s -- "$MGMT_ADMIN_PATH" "$github_user" "$gh_path" "$REPO_URL"
    ) < src/admin-repo-install.sh
    export MGMT_ANSIBLE_GALAXY="$(command -v ansible-galaxy)"
    ansible-playbook \
    -i localhost, \
    -c local \
    install.yml \
    --extra-vars "admin_local_repo=true" #--check
elif [ "$installation_type" = "odev_plugin" ]; then
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
