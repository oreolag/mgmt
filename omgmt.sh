#!/usr/bin/env bash
set -euo pipefail

launcher="${BASH_SOURCE[0]}"
if [[ -L "$launcher" ]]; then
  launcher="$(readlink "$launcher")"
fi
export OMGMT_PATH="$(cd "$(dirname "$launcher")" && pwd)"

# format
bold=$(tput bold 2>/dev/null || true)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

print_help() {
  local command_descriptions key description gh_description update new run delete
  command_descriptions="$("$OMGMT_PATH/src/cmd_description_read.sh" "$OMGMT_PATH" "ALL")"
  while IFS='=' read -r key description; do
    printf -v "$key" '%s' "$description"
  done <<< "$command_descriptions"

  echo "The management toolkit for your Oreol cluster."
  echo ""
  echo "${bold}USAGE${normal}"
  echo "  omgmt <command> <subcommand> [flags]"
  echo ""
  echo "${bold}CORE COMMANDS${normal}"
  echo "  gh:              $gh_description"
  echo "  update:          $update"
  echo ""
  echo "${bold}ANSIBLE COMMANDS${normal}"
  echo "  new:             $new"
  echo "  run:             $run"
  echo "  delete:          $delete"
  echo ""
  echo "  ${italic}Type omgmt followed by a space, then press Tab to explore commands.${normal}"
  echo ""
  echo "${bold}FLAGS${normal}"
  echo "  -h, --help       Show help for command"
  echo "  -v, --version    Show omgmt version"
  echo ""

  echo "${bold}EXAMPLES${normal}"
  echo "  $ omgmt run playbook"

  echo ""
  echo "${bold}LEARN MORE${normal}"
  echo "  Use ${bold}omgmt <command> <subcommand> --help${normal} for more information about a command."
  echo "  Read the manual at https://oreolag.github.io/docs/mgmt/"
}

print_version() {
  local ver date

  if [[ -f "$OMGMT_PATH/VERSION" ]]; then
    ver="$(cat "$OMGMT_PATH/VERSION")"
  else
    ver="unknown"
  fi

  if [[ -f "$OMGMT_PATH/RELEASE_DATE" ]]; then
    date="$(cat "$OMGMT_PATH/RELEASE_DATE")"
  else
    date="unknown"
  fi

  echo "omgmt version ${ver} (${date})"
  if [ "$ver" = "main" ]; then
    echo "https://github.com/oreolag/mgmt/tree/main"
  else
    echo "https://github.com/oreolag/mgmt/releases/tag/${ver}"
  fi
}

# ------------------------------------------------------------
# Global flags / help / version
# ------------------------------------------------------------
case "${1:-}" in
  ""|-h|--help)
    print_help
    exit 0
    ;;
  -v|--version)
    print_version
    exit 0
    ;;
esac

cmd="${1:-}"
subcmd="${2:-}"

if [[ ! "$cmd" =~ ^[a-z][a-z0-9_-]*$ || ( -n "$subcmd" && "$subcmd" != -* && ! "$subcmd" =~ ^[a-z][a-z0-9_-]*$ ) ]]; then
  echo "Command not found: $cmd $subcmd" >&2
  exit 1
fi

# ------------------------------------------------------------
# Script resolution with flag support
# ------------------------------------------------------------
if [[ -z "$cmd" || "$cmd" == -* ]]; then
  print_help
  exit 0
fi

# Single-command scripts: omgmt update [flags]
if [[ -z "$subcmd" || "$subcmd" == -* ]]; then
  script="${OMGMT_PATH}/cmd/${cmd}.sh"
  shift 1
else
  script="$OMGMT_PATH/cmd/$cmd/$subcmd.sh"
  shift 2
fi

if [[ ! -x "$script" ]]; then
  echo "Command not found: ${cmd} ${subcmd:-}"
  exit 1
fi

exec "$script" "$@"
