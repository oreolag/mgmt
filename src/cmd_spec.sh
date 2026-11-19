#!/usr/bin/env bash

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# derive from SCRIPT_DIR
PLAYBOOKS_USER_PATH="${OMGMT_CLUSTER_PATH:-$HOME/my_oreol_mgmt}/playbooks"

# format
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

# delete
DELETE_DESCRIPTION="Deletes an artifact of your choice"
DELETE_FLAGS=(
)
# cluster
DELETE_CLUSTER_DESCRIPTION="Deletes an existing cluster"
DELETE_CLUSTER_FLAGS=(
  "name,n,Cluster name,-,-"
)
DELETE_CLUSTER_FLAGS_MANDATORY="name"
# playbook
DELETE_PLAYBOOK_DESCRIPTION="Deletes an existing user playbook"
DELETE_PLAYBOOK_FLAGS=(
  "name,n,Playbook name,-,-"
)
DELETE_PLAYBOOK_FLAGS_MANDATORY="name"

# new
NEW_DESCRIPTION="Create a cluster or a playbook and role"
NEW_FLAGS=(
)
# cluster
NEW_CLUSTER_DESCRIPTION="Creates a cluster from starter templates"
NEW_CLUSTER_FLAGS=(
  "name,n,Cluster name,-,-"
)
NEW_CLUSTER_FLAGS_MANDATORY="name"
# playbook
NEW_PLAYBOOK_DESCRIPTION="Adds a new playbook to ${bold}$PLAYBOOKS_USER_PATH${normal}"
NEW_PLAYBOOK_FLAGS=(
  "name,n,Playbook name,-,-"
)
NEW_PLAYBOOK_FLAGS_MANDATORY="name"

# run
RUN_DESCRIPTION="Run an Ansible playbook"
RUN_FLAGS=(
)
# playbook
RUN_PLAYBOOK_DESCRIPTION="Runs a playbook on the selected hosts"
RUN_PLAYBOOK_FLAGS=(
  "cluster,c,Cluster name (required when more than one exists),-,-"
  "hosts,,Target host or group from the management inventory (default: local),-,local"
  "name,n,Playbook name,-,-"
  "vars,v,Extra variables (example: \"force=true value=10\"),-,-"
)
RUN_PLAYBOOK_FLAGS_MANDATORY="name"

# update
UPDATE_DESCRIPTION="Update omgmt to the latest release/main version"
UPDATE_FLAGS=(
  "main,m,Use main branch instead of release,-,-"
)

# GitHub
GH_DESCRIPTION="GitHub support for my_oreol_mgmt"
GH_FLAGS=(
)
# push
GH_PUSH_DESCRIPTION="Pushes the current branch to origin"
GH_PUSH_FLAGS=()
GH_PUSH_FLAGS_MANDATORY=""
# pull
GH_PULL_DESCRIPTION="Pulls changes from origin into the current branch"
GH_PULL_FLAGS=(
)
GH_PULL_FLAGS_MANDATORY=""
# diff
GH_DIFF_DESCRIPTION="Shows uncommitted changes in my_oreol_mgmt"
GH_DIFF_FLAGS=()
GH_DIFF_FLAGS_MANDATORY=""
# status
GH_STATUS_DESCRIPTION="Fetches origin and shows Git status"
GH_STATUS_FLAGS=()
GH_STATUS_FLAGS_MANDATORY=""
