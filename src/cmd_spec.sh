#!/usr/bin/env bash

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# derive from SCRIPT_DIR
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"
WORKFLOWS_PATH="$SCRIPT_DIR/../submodules/workflows"

# constants
WORKFLOWS_REPOSITORY="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github workflows_repo)")"
PLAYBOOKS_USER_PATH="$(python3 "$ODEV_PATH/src/odev_path.py" playbooks)" || return 1
WORKFLOWS_PUSH_BRANCH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_workflows)"
WORKFLOWS_REPO="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github workflows_repo)"
PLAYBOOKS_PUSH_BRANCH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_playbooks)"
PLAYBOOKS_REPO="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github playbooks_repo)"
WORKFLOWS_USER_PATH="$(python3 "$ODEV_PATH/src/odev_path.py" workflows)" || return 1
INVENTORY_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths inventory)")"

#if [[ -f "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH" ]]; then
#  WORKFLOWS_PUSH_BRANCH="$(cat "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH")"
#else
#  WORKFLOWS_PUSH_BRANCH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_workflows)"
#fi

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

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
RUN_DESCRIPTION="Accelerated application execution"
RUN_FLAGS=(
)
# playbook
RUN_PLAYBOOK_DESCRIPTION="Runs a playbook on the selected hosts"
RUN_PLAYBOOK_FLAGS=(
  "name,n,Playbook name,-,-"
  "hosts,,Target host or group from ${bold}$INVENTORY_PATH/hosts_$USER${normal} (default: local),-,local"
  "vars,v,Extra variables (example: \"force=true value=10\"),-,-"
)
RUN_PLAYBOOK_FLAGS_MANDATORY="name"

# update
UPDATE_DESCRIPTION="Update odev to the latest release/main version"
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
  "workflows,w,${bold}$WORKFLOWS_REPO${normal}:${bold}$WORKFLOWS_PUSH_BRANCH${normal},-,-"
  "playbooks,p,${bold}$PLAYBOOKS_REPO${normal}:${bold}$PLAYBOOKS_PUSH_BRANCH${normal},-,-"
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

# workflows
workflows=()
for d in "$WORKFLOWS_PATH"/*/; do
  workflows+=("$(basename "$d")")
done

# source cmd_spec.sh for workflows
for wf in "${workflows[@]}"; do
  wf_i="$SCRIPT_DIR/../submodules/workflows/$wf/cmd_spec.sh"
  [[ -f "$wf_i" ]] && source "$wf_i"
done

# user workflows
workflows_user=()
if [[ -d "$WORKFLOWS_USER_PATH" ]]; then
  for d in "$WORKFLOWS_USER_PATH"/*; do
    [[ -d "$d" ]] || continue
    workflows_user+=("$(basename "$d")")
  done
fi

# source cmd_spec.sh for user workflows not in workflows
for wf in "${workflows_user[@]}"; do
  [[ " ${workflows[*]} " =~ " $wf " ]] && continue
  wf_i="$WORKFLOWS_USER_PATH/$wf/cmd_spec.sh"
  [[ -f "$wf_i" ]] && source "$wf_i"
done
