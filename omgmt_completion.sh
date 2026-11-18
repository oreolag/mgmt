#!/usr/bin/env bash
# Top-level and subcommand completion for the management CLI.
if [[ -n ${ZSH_VERSION:-} ]] && ! typeset -f complete >/dev/null; then
  autoload -Uz compinit bashcompinit
  if ! typeset -f compdef >/dev/null; then
    compinit
  fi
  bashcompinit
fi

_omgmt_complete() {
  local current command_path root file candidate
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
  esac
  return 0
}

complete -F _omgmt_complete omgmt
