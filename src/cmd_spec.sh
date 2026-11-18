#!/usr/bin/env bash

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# derive from SCRIPT_DIR
PLAYBOOKS_USER_PATH="${OMGMT_PATH:-$(dirname "$SCRIPT_DIR")}/playbooks"

# format
bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

# delete
DELETE_DESCRIPTION="Deletes an artifact of your choice"
DELETE_FLAGS=(
)
# playbook
DELETE_PLAYBOOK_DESCRIPTION="Deletes an existing user playbook"
DELETE_PLAYBOOK_FLAGS=(
  "name,n,Playbook name,-,-"
)
DELETE_PLAYBOOK_FLAGS_MANDATORY="name"

# new
NEW_DESCRIPTION="Create a new playbook and role"
NEW_FLAGS=(
)
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
  "name,n,Playbook name,-,-"
  "hosts,,Target host or group from the management inventory (default: local),-,local"
  "vars,v,Extra variables (example: \"force=true value=10\"),-,-"
)
RUN_PLAYBOOK_FLAGS_MANDATORY="name"

# update
UPDATE_DESCRIPTION="Update omgmt to the latest release/main version"
UPDATE_FLAGS=(
  "main,m,Use main branch instead of release,-,-"
)

# GitHub
GH_DESCRIPTION="GitHub support for community repositories" #"Manage and share your workflows and playbooks"
GH_FLAGS=(
)
# push
GH_PUSH_DESCRIPTION="Pushes your changes to your GitHub fork"
GH_PUSH_FLAGS=(
  "workflow,w,Workflow name,-,-"
  "playbook,p,Playbook name,-,-"
)
GH_PUSH_FLAGS_MANDATORY=""
# pull
GH_PULL_DESCRIPTION="Fetches and merges community main and fork branches locally"
GH_PULL_FLAGS=(
)
GH_PULL_FLAGS_MANDATORY=""
# pr
GH_PR_DESCRIPTION="Proposes your changes to the community repository"
GH_PR_FLAGS=(
  "workflow,w,Workflow name,-,-"
  "playbook,p,Playbook name,-,-"
)
GH_PR_FLAGS_MANDATORY=""
# diff
GH_DIFF_DESCRIPTION="Shows uncommitted changes to your workflow or playbook"
GH_DIFF_FLAGS=(
  "workflow,w,Workflow name,-,-"
  "playbook,p,Playbook name,-,-"
  "file,f,Workflow file name (optional),-,-"
)
GH_DIFF_FLAGS_MANDATORY=""
