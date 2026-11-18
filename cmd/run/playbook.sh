#!/bin/bash

# example: odev run playbook --name test

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBCOMMAND="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
OMGMT_PATH="${OMGMT_PATH:-"$(dirname "$(dirname "$SCRIPT_DIR")")"}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
PLAYBOOKS_USER_PATH="$(python3 "$OMGMT_PATH/src/odev_path.py" playbooks)" || exit 1
MGMT_PATH="$(eval echo "$("$OMGMT_PATH/src/read_yml.py" --db "$OMGMT_PATH/vars.yml" paths mgmt)")"
INVENTORY_PATH="$(eval echo "$("$OMGMT_PATH/src/read_yml.py" --db "$OMGMT_PATH/vars.yml" paths inventory)")"

# check on users
is_odev_developer=$($OMGMT_PATH/src/is_member.sh $USER odev-developers)
if [ "$is_odev_developer" = "0" ]; then
  echo "Permission denied: $USER"
  exit 1
fi

# set KEY
KEY="$(printf '%s_%s' "$COMMAND" "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags, mandatory flags
command_description="$("$OMGMT_PATH/src/cmd_description_read.sh" "$OMGMT_PATH" "$KEY")"
mapfile -t flags < <("$OMGMT_PATH/src/cmd_flags_read.sh" "$OMGMT_PATH" "$KEY")
mandatory_flags="$("$OMGMT_PATH/src/cmd_mandatory_flags_read.sh" "$OMGMT_PATH" "$KEY")"

# (maybe) print help
print_range="0"
print_default="0"
print_both="0"
"$OMGMT_PATH/src/cmd_help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" \
  "${flags[@]}" -- "$@" && exit 0 || true

# parse flags
parsed_flags="$("$OMGMT_PATH/src/cmd_parse.sh" --params "${flags[@]}" -- "$@")" || exit 1

# check supplied values first, then check each answer before the next question
for field in "" ${mandatory_flags//,/ }; do
  if [[ -n "$field" && "${V[$field]:--}" != "-" ]]; then
    continue
  fi
  # run interactive prompt
  parsed_flags="$("$OMGMT_PATH/src/cmd_prompt.sh" --required "$mandatory_flags" --field "$field" --params "${flags[@]}" -- "$parsed_flags")" || exit 1

  # read flags
  if [[ -n "$parsed_flags" ]]; then
    declare -A V
    while IFS='=' read -r k v; do
      V["$k"]="$v"
    done <<< "$parsed_flags"
  fi

  # assign flags
  name=${V[name]:--}
  hosts=${V[hosts]:-local}
  vars=${V[vars]:--}

  if [[ "$name" != "-" ]]; then
    # check on name
    if [[ ! "$name" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
      echo "Invalid playbook name: $name"
      exit 1
    fi

    # check if exists
    playbook="$PLAYBOOKS_USER_PATH/$name.yml"
    if [[ ! -f "$playbook" ]]; then
      echo "Playbook does not exist: $name"
      exit 1
    fi
  fi

done

# refresh and use the user's generated inventory
"$OMGMT_PATH/src/get_ansible_hosts.sh" "$(id -un)" || exit 1
inventory_file="$INVENTORY_PATH/hosts_$(id -un)"

# extra variables override the playbook defaults
args=()
if [[ "$vars" != "-" ]]; then
  args+=(--extra-vars "$vars")
  # Supply the example task with names; Ansible still parses the original values.
  var_names="$(python3 "$OMGMT_PATH/src/playbook_var_names.py" "$vars")" || exit 1
  args+=(--extra-vars "$var_names")
fi

# run the playbook on the selected hosts
exec "$MGMT_PATH/ansible-play.sh" "$playbook" "$hosts" -i "$inventory_file" "${args[@]}"

# author: https://github.com/jmoya82
