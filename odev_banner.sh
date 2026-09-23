#!/usr/bin/env bash
set -euo pipefail

bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

year=$(date +%Y)

center() {
    local text=$1
    local formatted=${2:-$1}
    local left=$(( (51 - ${#text}) / 2 ))
    local right=$(( 51 - ${#text} - left ))
    printf '|%*s%s%*s|\n' "$left" '' "$formatted" "$right" ''
}

echo ""
echo "+---------------------------------------------------+"
center ""
center ""
center "OREOL Heterogenius computing" "${bold}OREOL${normal} Hetero${italic}genius${normal} computing"
center ""
center "To start using your cluster," "${italic}To start using your cluster,${normal}"
center "type odev to explore the available commands." "${italic}type odev to explore the available commands.${normal}"
center ""
center "(C) $year OREOL KLG. All rights reserved."
center ""
center ""
echo "+---------------------------------------------------+"
#echo ""