#!/usr/bin/env bash
# Complete management commands and the flags defined in cmd_spec.sh.
if [[ -n ${ZSH_VERSION:-} ]] && ! typeset -f complete >/dev/null; then
  autoload -Uz compinit bashcompinit
  if ! typeset -f compdef >/dev/null; then
    compinit
  fi
  bashcompinit
fi

_omgmt_complete() {
  local current command_path root file candidate key flag_specs name short prev workspace
  COMPREPLY=()
  current=${COMP_WORDS[COMP_CWORD]}
  command_path=$(command -v -- "${COMP_WORDS[0]}") || return 0
  if [[ -L "$command_path" ]]; then
    command_path=$(readlink "$command_path") || return 0
  fi
  root=$(cd -- "$(dirname -- "$command_path")" && pwd) || return 0

  case $COMP_CWORD in
    1)
      for candidate in --help --version; do
        [[ $candidate == "$current"* ]] && COMPREPLY+=("$candidate")
      done
      for file in "$root"/cmd/*.sh; do
        [[ -x "$file" ]] || continue
        candidate=${file##*/}
        candidate=${candidate%.sh}
        [[ $candidate == "$current"* ]] && COMPREPLY+=("$candidate")
      done
      ;;
    2)
      [[ -x "$root/cmd/${COMP_WORDS[1]}.sh" ]] || return 0
      for candidate in -h --help; do
        [[ $candidate == "$current"* ]] && COMPREPLY+=("$candidate")
      done
      [[ $current != -* && -d "$root/cmd/${COMP_WORDS[1]}" ]] || return 0
      for file in "$root/cmd/${COMP_WORDS[1]}"/*.sh; do
        [[ -x "$file" ]] || continue
        candidate=${file##*/}
        candidate=${candidate%.sh}
        [[ $candidate == "$current"* ]] && COMPREPLY+=("$candidate")
      done
      ;;
    *)
      [[ -f "$root/cmd/${COMP_WORDS[1]}/${COMP_WORDS[2]}.sh" &&
         -x "$root/cmd/${COMP_WORDS[1]}/${COMP_WORDS[2]}.sh" ]] || return 0
      prev=${COMP_WORDS[COMP_CWORD-1]}
      if [[ "${COMP_WORDS[1]}" == delete && ( "$prev" == --name || "$prev" == -n ) ]]; then
        workspace="${OMGMT_CLUSTER_PATH:-$HOME/my_oreol_mgmt}"
        case "${COMP_WORDS[2]}" in
          cluster)
            while IFS= read -r candidate; do
              [[ $candidate =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ && $candidate == "$current"* ]] &&
                COMPREPLY+=("$candidate")
            done < <(git -C "$workspace" ls-tree -d --name-only HEAD:clusters 2>/dev/null)
            ;;
          playbook)
            while IFS= read -r candidate; do
              [[ $candidate != cli_install && $candidate =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ &&
                 $candidate == "$current"* ]] && COMPREPLY+=("$candidate")
            done < <(
              {
                git -C "$workspace" ls-tree --name-only HEAD:playbooks 2>/dev/null |
                  sed -nE 's/\.ya?ml$//p'
                git -C "$workspace" ls-tree -d --name-only HEAD:roles 2>/dev/null
              } | sort -u
            )
            ;;
        esac
        return 0
      fi
      key="$(printf '%s_%s' "${COMP_WORDS[1]}" "${COMP_WORDS[2]}" | tr '[:lower:]' '[:upper:]')"
      flag_specs="$("$root/src/cmd_flags_read.sh" "$root" "$key")" || return 0
      local candidates=(-h --help)
      while IFS=, read -r name short _; do
        [[ -n "$name" ]] || continue
        candidates+=("--$name")
        [[ -z "$short" ]] || candidates+=("-$short")
      done <<< "$flag_specs"
      for candidate in "${candidates[@]}"; do
        [[ $candidate == "$current"* ]] && COMPREPLY+=("$candidate")
      done
      ;;
  esac
  return 0
}

complete -F _omgmt_complete omgmt
