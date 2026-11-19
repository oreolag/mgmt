#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_parse.sh --params "${FLAGS[@]}" -- "$@"
# Output:
#   key=value   (one per line)

[[ "${1:-}" == "--params" ]] || exit 2
shift

PARAMS=()
while [[ "${1:-}" != "--" ]]; do
  PARAMS+=("$1")
  shift
done
shift # consume --

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_value() {
  local name="$1"
  local value="$2"
  local range="$3"

  # empty range => accept anything
  [[ -z "$range" ]] && return 0

  # enum: a|b|c
  if [[ "$range" == *"|"* ]]; then
    local ok=0
    IFS='|' read -r -a choices <<< "$range"
    for c in "${choices[@]}"; do
      [[ "$value" == "$c" ]] && { ok=1; break; }
    done
    [[ "$ok" == "1" ]] && return 0
    echo "Invalid value for --$name: '$value' (allowed: $range)" >&2
    return 1
  fi

  # int range: N-M
  if [[ "$range" =~ ^[0-9]+-[0-9]+$ ]]; then
    local lo="${range%-*}"
    local hi="${range#*-}"
    if ! is_int "$value"; then
      echo "Invalid value for --$name: '$value' (expected integer in range: $range)" >&2
      return 1
    fi
    if (( value < lo || value > hi )); then
      echo "Invalid value for --$name: '$value' (expected range: $range)" >&2
      return 1
    fi
    return 0
  fi

  # unknown pattern => accept (or tighten later)
  return 0
}

# parse argv
while [[ $# -gt 0 ]]; do
  matched=false
  for p in ${PARAMS[@]+"${PARAMS[@]}"}; do
    IFS=',' read -r name short desc range def <<< "$p"
    if [[ "$1" == "--$name" || ( -n "$short" && "$1" == "-$short" ) ]]; then
      if [[ $# -lt 2 || -z "$2" || "$2" == --* || "$2" =~ ^-[[:alpha:]] ]]; then
        echo "Missing value for $1" >&2
        exit 1
      fi
      val="$2"
      validate_value "$name" "$val" "$range"
      printf -v "value_$name" '%s' "$val"
      shift 2
      matched=true
      break
    fi
  done

  [[ "$matched" == true ]] || { echo "Unknown flag: $1" >&2; exit 1; }
done

# Emit only supplied flags. Use named variables for Bash 3 compatibility.
for p in ${PARAMS[@]+"${PARAMS[@]}"}; do
  IFS=',' read -r name _ <<< "$p"
  key="value_$name"
  if declare -p "$key" >/dev/null 2>&1; then
    value="${!key}"
    # Keep multiline extra vars in a single key=value record.
    if [[ "$name" == vars && ( "$value" == *$'\n'* || "$value" == %* ) ]]; then
      value="${value//%/%25}"
      value="%${value//$'\n'/%0A}"
    fi
    printf '%s=%s\n' "$name" "$value"
  fi
done
