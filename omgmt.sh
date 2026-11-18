#!/usr/bin/env bash
set -euo pipefail

export OMGMT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# early exit
#is_odev_user=$($ODEV_PATH/src/is_member.sh $USER odev-users)
#if [ "$is_odev_user" = "0" ]; then
#  exit 1
#fi

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
#CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths cmdb)")"
#PLAYBOOKS_PATH="$(python3 "$ODEV_PATH/src/odev_path.py" playbooks)" || exit 1
#WORKFLOWS_PATH="$(python3 "$ODEV_PATH/src/odev_path.py" workflows)" || exit 1

# command descriptions
command_descriptions="$("$OMGMT_PATH/src/cmd_description_read.sh" "$OMGMT_PATH" "ALL")"
while IFS='=' read -r key description; do
  printf -v "$key" '%s' "$description"
done <<< "$command_descriptions"

# check on GitHub CLI
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
gh_status=""
wf_repo_status=""
pb_repo_status=""
if [[ "$installed" == "1" ]]; then
  logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
  if [[ "$logged_in" == "1" ]]; then
    github_user="$(gh api user --jq .login 2>/dev/null)" || github_user=""
    if [[ -n "$github_user" ]]; then
      gh_status="You are logged into the GitHub CLI as ${bold}$github_user${normal}"
    fi   
  else
    gh_status="Please authenticate with the GitHub CLI using ${bold}gh auth login${normal}"
  fi
else
  gh_status="Please install the GitHub CLI"
fi

# check on community repositories
# workflows
#if [ ! -d "$WORKFLOWS_PATH" ]; then
#  wf_repo_status="Create a new accelerated workflow with ${bold}odev new workflow${normal}"
#else
#  wf_repo_status="Continue working on your workflows in ${bold}$WORKFLOWS_PATH${normal}"
#fi

# playbooks
#if [ ! -d "$PLAYBOOKS_PATH" ]; then
#  pb_repo_status="Add a new Ansible playbook with ${bold}odev new playbook${normal}"
#else
#  pb_repo_status="Find your playbooks in ${bold}$PLAYBOOKS_PATH${normal}"
#fi

# check on tailscale
installed="$("$OMGMT_PATH/src/required_tools_print.sh" "$OMGMT_PATH" "tailscale")"
ts_status=""
if [[ "$installed" == "1" ]]; then
  logged_in="$("$OMGMT_PATH/src/tailscale_auth_status.sh")"
  if [[ "$logged_in" == "1" ]]; then
    ts_user="$(tailscale whoami 2>/dev/null | awk '/^User:/ {user=1; next} user && $1 == "Name:" {print $2; exit}')" || ts_user=""
    if [[ -n "$ts_user" ]]; then
      ts_status="Tailscale is connected as ${bold}$ts_user${normal}"
    #else
    #  ts_status="Tailscale is connected"
    fi
  else
    ts_status="Tailscale is not connected. Log in to start using ${bold}sudo tailscale up --ssh${normal}"
  fi
else
  ts_status="Please install the Tailscale CLI"
fi

# check on build
# Booking status is optional; configuration errors must not disable other commands.
#if ! is_booking=$("$ODEV_PATH/src/is_server.sh" "$ODEV_PATH" "booking"); then
#  is_booking=0
#fi
#is_build=$($ODEV_PATH/src/is_server.sh "$ODEV_PATH" "build")

print_help() {
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

  # print gh_status
  if [ ! "$gh_status" = "" ]; then
    echo "  $gh_status"
  fi

  # print ts_status
  if [ ! "$ts_status" = "" ]; then
    echo "  $ts_status"
  fi
  print_booking_status

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

# ------------------------------------------------------------
# Script resolution with flag support
# ------------------------------------------------------------
if [[ -z "$cmd" || "$cmd" == -* ]]; then
  print_help
  exit 0
fi

# Single-command scripts: odev examine [flags]
if [[ -z "$subcmd" || "$subcmd" == -* ]]; then
  script="${OMGMT_PATH}/cmd/${cmd}.sh"
  shift 1
else
  script="$("$OMGMT_PATH/src/workflow_command_path.sh" "$OMGMT_PATH" "$cmd" "$subcmd")" || script=""
  shift 2
fi

if [[ ! -x "$script" ]]; then
  echo "Command not found: ${cmd} ${subcmd:-}"
  exit 1
fi

exec "$script" "$@"
