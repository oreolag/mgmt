# Bash completion for the mgmt playbook wrapper.
_oreol_ansible_play_complete() {
    local current command_path cluster_dir file name
    COMPREPLY=()
    current=${COMP_WORDS[COMP_CWORD]}

    command_path=${COMP_WORDS[0]}
    if [[ $command_path != */* ]]; then
        command_path=$(type -P -- "$command_path") || return 0
    fi
    cluster_dir=$(cd -- "$(dirname -- "$command_path")" 2>/dev/null && pwd) || return 0

    case $COMP_CWORD in
        1)
            for file in "$cluster_dir"/collections/ansible_collections/oreol/mgmt/playbooks/*; do
                [[ -f $file ]] || continue
                case $file in
                    *.yml) name=${file##*/}; name=${name%.yml} ;;
                    *.yaml) name=${file##*/}; name=${name%.yaml} ;;
                    *) continue ;;
                esac
                [[ $name =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || continue
                if [[ $current == oreol.mgmt.* ]]; then
                    name="oreol.mgmt.$name"
                fi
                [[ $name == "$current"* ]] && COMPREPLY+=("$name")
            done
            ;;
        2)
            [[ -r $cluster_dir/hosts ]] || return 0
            while IFS= read -r name; do
                [[ $name == "$current"* ]] && COMPREPLY+=("$name")
            done < <(awk '
                /^[[:space:]]*\[/ {
                    group = $0
                    sub(/^[[:space:]]*\[/, "", group)
                    sub(/\].*$/, "", group)
                    sub(/:(children|vars)$/, "", group)
                    if (group ~ /^[a-zA-Z_][a-zA-Z0-9_]*$/) print group
                }
            ' "$cluster_dir/hosts" | sort -u)
            ;;
    esac
    return 0
}

complete -F _oreol_ansible_play_complete ansible-play.sh
