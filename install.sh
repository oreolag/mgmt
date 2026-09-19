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

git clone --recursive "$REPO_URL" "$TMP_PATH/mgmt"

cd "$TMP_PATH/mgmt"

echo ""
echo "${bold}[INFO] Running installer...${normal}"

if [ "$installation_type" = "" ] || [ "$installation_type" = "admin_local_repo" ]; then
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
