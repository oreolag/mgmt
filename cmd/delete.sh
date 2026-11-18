#!/bin/bash

# example: omgmt delete

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="delete"

CLI_NAME="omgmt"
SUBCOMMAND="-"
OMGMT_PATH="${OMGMT_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# read workflow description
KEY="$(printf '%s' "$COMMAND" | tr '[:lower:]' '[:upper:]')"
command_description="$("$OMGMT_PATH/src/cmd_description_read.sh" "$OMGMT_PATH" "$KEY")"

# read workflow commands
commands=()
while IFS= read -r line; do
  commands+=("$line")
done < <(bash "$OMGMT_PATH/src/cmd_subcommands_read.sh" "$OMGMT_PATH" "$KEY")

# print help
print_range="-"
print_default="-"
print_both="-"      
"$OMGMT_PATH/src/cmd_help_print.sh" --print \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" "${commands[@]}" -- "$@" && exit 0 || true
