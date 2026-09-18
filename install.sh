#!/usr/bin/env bash

set -euo pipefail

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

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

# ubuntu check
if [[ -f /etc/os-release ]]; then
    . /etc/os-release

    if [[ "$ID" != "ubuntu" ]]; then
        echo "Error: mgmt requires Ubuntu"
        exit 1
    fi
else
    echo "Error: cannot determine operating system"
    exit 1
fi

#echo "REPO_URL: $REPO_URL"

#echo "Hey I am here"
#exit 

echo "${bold}[INFO] Installing prerequisites...${normal}"

apt-get update

apt-get install -y \
    git \
    ansible \
    python3 \
    python3-pip \
    sudo

echo ""
echo "${bold}[INFO] Cloning mgmt repository...${normal}"

git clone --recursive "$REPO_URL" "$TMP_PATH/mgmt"

cd "$TMP_PATH/mgmt"

echo ""
echo "${bold}[INFO] Running installer...${normal}"

ansible-playbook \
    -i localhost, \
    -c local \
    install.yml \
    --extra-vars "repo=true" #--check

echo "${bold}${COLOR_PASSED}✓${normal} mgmt installation completed${normal}"