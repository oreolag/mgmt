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
  local current command_path root file candidate key flag_specs name short prev workspace value_kind
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
      if [[ ${COMP_WORDS[1]} == update && $current == -* ]]; then
        for candidate in -m --main; do
          [[ $candidate == "$current"* ]] && COMPREPLY+=("$candidate")
        done
      fi
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
      case "${COMP_WORDS[1]}:${COMP_WORDS[2]}:$prev" in
        delete:cluster:--name|delete:cluster:-n|run:playbook:--cluster|run:playbook:-c)
          value_kind=cluster ;;
        delete:playbook:--name|delete:playbook:-n|run:playbook:--name|run:playbook:-n)
          value_kind=playbook ;;
      esac
      if [[ -n "${value_kind:-}" ]]; then
        workspace="${OMGMT_CLUSTER_PATH:-}"
        if [[ -z "$workspace" && -r "$HOME/.config/omgmt/workspace" ]]; then
          workspace="$(cat "$HOME/.config/omgmt/workspace")"
        fi
        workspace="${workspace:-$HOME/my_oreol_mgmt}"
        case "$value_kind" in
          cluster)
            while IFS= read -r file; do
              candidate=${file##*/}
              [[ $candidate =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ && $candidate == "$current"* ]] &&
                COMPREPLY+=("$candidate")
            done < <(find "$workspace/clusters" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
            ;;
          playbook)
            local collection_playbooks="$root/collections/ansible_collections/oreol/mgmt/playbooks"
            while IFS= read -r candidate; do
              [[ $candidate =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ && $candidate == "$current"* ]] || continue
              if [[ "${COMP_WORDS[1]}" == delete ]]; then
                [[ $candidate != cli_install ]] || continue
              else
                if [[ ! -f "$workspace/playbooks/$candidate.yml" && ! -f "$workspace/playbooks/$candidate.yaml" ]]; then
                  [[ $candidate =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
                  [[ -f "$collection_playbooks/$candidate.yml" || -f "$collection_playbooks/$candidate.yaml" ]] || continue
                fi
              fi
              COMPREPLY+=("$candidate")
            done < <(
              {
                find "$workspace/playbooks" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) \
                  2>/dev/null | sed -nE 's|.*/([^/]+)\.ya?ml$|\1|p'
                if [[ "${COMP_WORDS[1]}" == delete ]]; then
                  find "$workspace/roles" -mindepth 1 -maxdepth 1 -type d 2>/dev/null |
                    sed 's|.*/||'
                else
                  find "$collection_playbooks" -mindepth 1 -maxdepth 1 \( -type f -o -type l \) 2>/dev/null |
                    sed -nE 's|.*/([^/]+)\.ya?ml$|\1|p'
                fi
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
