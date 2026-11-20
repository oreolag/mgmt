#!/usr/bin/env bash
set -euo pipefail

launcher="${BASH_SOURCE[0]}"
if [[ -L "$launcher" ]]; then
  launcher="$(readlink "$launcher")"
fi
export OMGMT_PATH="$(cd "$(dirname "$launcher")" && pwd)"
if [[ -z "${OMGMT_CLUSTER_PATH:-}" && -r "$HOME/.config/omgmt/workspace" ]]; then
  OMGMT_CLUSTER_PATH="$(cat "$HOME/.config/omgmt/workspace")"
fi
export OMGMT_CLUSTER_PATH="${OMGMT_CLUSTER_PATH:-$HOME/my_oreol_mgmt}"

# format
bold=$(tput bold 2>/dev/null || true)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

print_server_status() {
  local github_user ts_user
  printf '\n%sHOST STATUS%s\n' "$bold" "$normal"

  if ! command -v gh >/dev/null 2>&1; then
    echo "  Please install the GitHub CLI"
  elif github_user="$(gh api --hostname github.com user --jq .login 2>/dev/null)" && [[ -n "$github_user" ]]; then
    printf '  You are logged into the GitHub CLI as %s%s%s\n' "$bold" "$github_user" "$normal"
  else
    printf '  GitHub CLI account unavailable. To log in, use %sgh auth login%s\n' "$bold" "$normal"
  fi

  if ! command -v tailscale >/dev/null 2>&1; then
    echo "  Please install the Tailscale CLI"
  elif [[ "$("$OMGMT_PATH/src/tailscale_auth_status.sh")" == 1 ]]; then
    if ts_user="$(tailscale whoami 2>/dev/null | awk '/^User:/ {user=1; next} user && $1 == "Name:" {print $2; exit}')" &&
       [[ -n "$ts_user" ]]; then
      printf '  Tailscale is connected as %s%s%s\n' "$bold" "$ts_user" "$normal"
    else
      echo "  Tailscale is connected"
    fi
  else
    echo "  Tailscale is not connected"
  fi
}

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
  echo "${bold}MGMT COMMANDS${normal}"
  echo "  new:             $new"
  echo "  run:             $run"
  echo "  delete:          $delete"
  echo ""
  echo "  ${italic}Type omgmt followed by a space, then press Tab to explore commands.${normal}"
  echo ""
  echo "${bold}FLAGS${normal}"
  echo "  -h, --help       Show help for command"
  echo "  -v, --version    Show omgmt version"

  print_server_status

  echo ""
  echo "${bold}EXAMPLES${normal}"
  echo "  $ omgmt run playbook"

  echo ""
  echo "${bold}LEARN MORE${normal}"
  echo "  Use ${bold}omgmt <command> <subcommand> --help${normal} for more information about a command."
  echo "  Read the manual at https://oreolag.github.io/docs/mgmt/"
}

print_command_help() {
  local command="$1" subcommand="$2" key description flag_specs flag
  local flags=()

  if [[ -z "$subcommand" ]]; then
    key="$command"
    subcommand="$command"
    command="-"
  else
    key="${command}_${subcommand}"
  fi
  key="$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]')"
  description="$("$OMGMT_PATH/src/cmd_description_read.sh" "$OMGMT_PATH" "$key")" || return 1
  flag_specs="$("$OMGMT_PATH/src/cmd_flags_read.sh" "$OMGMT_PATH" "$key")" || return 1
  while IFS= read -r flag; do
    [[ -n "$flag" ]] && flags+=("$flag")
  done <<< "$flag_specs"
  "$OMGMT_PATH/src/cmd_help_print.sh" --print omgmt "$command" "$subcommand" \
    "$description" 0 0 0 ${flags[@]+"${flags[@]}"}
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
    echo "https://github.com/oreolag/mgmt/releases/tag/v${ver#v}"
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

# Print help before the command checks its runtime dependencies.
if [[ "$script" == "$OMGMT_PATH/cmd/"*/* || "$cmd" == update ]]; then
  for arg in "$@"; do
    case "$arg" in
      -h|--help)
        if [[ "$cmd" == update && "$subcmd" == -* ]]; then
          subcmd=""
        fi
        print_command_help "$cmd" "$subcmd"
        exit $?
        ;;
    esac
  done
fi

exec "$script" "$@"
