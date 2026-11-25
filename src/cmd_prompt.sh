#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_prompt.sh --required "name,type" --params "${FLAGS[@]}" -- "$parsed_flags"
# Optional: --field NAME asks only for NAME; --field "" only fills optional defaults.
# Output:
#   key=value   (one per line)  (updated)

[[ "${1:-}" == "--required" ]] || exit 2
required_csv="${2:-}"; shift 2

prompt_required="$required_csv"
if [[ "${1:-}" == "--field" ]]; then
  prompt_required="$2"
  shift 2
fi

[[ "${1:-}" == "--params" ]] || exit 2
shift

PARAMS=()
while [[ "${1:-}" != "--" ]]; do
  PARAMS+=("$1")
  shift
done
shift # consume --

# Read existing parsed flags (passed as ONE multi-line argument)

while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == *=* ]] || continue
  k="${line%%=*}"; v="${line#*=}"
  [[ "$k" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || exit 2
  printf -v "value_$k" '%s' "$v"
done < <(printf '%s\n' "${1:-}")

# Build meta from PARAMS
for p in ${PARAMS[@]+"${PARAMS[@]}"}; do
  IFS=',' read -r name short desc range def <<< "$p"
  printf -v "range_$name" '%s' "$range"
  printf -v "raw_default_$name" '%s' "$def"
  # Treat "-" as "no default" for prompting purposes
  if [[ "$def" == "-" ]]; then
    printf -v "default_$name" '%s' ""
  else
    printf -v "default_$name" '%s' "$def"
  fi
done

# NEW: build set of mandatory flags (from --required "a,b,c")
IFS=',' read -r -a __REQ <<< "$required_csv"
for m in ${__REQ[@]+"${__REQ[@]}"}; do
  m="${m#"${m%%[![:space:]]*}"}"
  m="${m%"${m##*[![:space:]]}"}"
  [[ -n "$m" ]] && printf -v "mandatory_$m" '%s' 1
done

# NEW: ensure all NON-mandatory flags exist in V with their default (including "-" or "1")
for p in ${PARAMS[@]+"${PARAMS[@]}"}; do
  IFS=',' read -r name short desc range def <<< "$p"
  mandatory_key="mandatory_$name"
  value_key="value_$name"
  if [[ -z "${!mandatory_key:-}" ]] && ! declare -p "$value_key" >/dev/null 2>&1; then
    printf -v "$value_key" '%s' "$def"
  fi
done

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_value() {
  local value="$1" range="$2"

  # empty range => accept anything
  [[ -z "$range" ]] && return 0

  # enum: a|b|c
  if [[ "$range" == *"|"* ]]; then
    IFS='|' read -r -a choices <<< "$range"
    for c in "${choices[@]}"; do
      [[ "$value" == "$c" ]] && return 0
    done
    return 1
  fi

  # int range: N-M
  if [[ "$range" =~ ^[0-9]+-[0-9]+$ ]]; then
    local lo="${range%-*}"
    local hi="${range#*-}"
    is_int "$value" || return 1
    (( value >= lo && value <= hi )) || return 1
    return 0
  fi

  return 0
}

IFS=',' read -r -a REQUIRED <<< "$prompt_required"
for name in ${REQUIRED[@]+"${REQUIRED[@]}"}; do
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"

  [[ -n "$name" ]] || continue

  value_key="value_$name"
  range_key="range_$name"
  default_key="default_$name"
  raw_default_key="raw_default_$name"

  # Treat "name=-" (from cmd_parse default) as missing if RAW default was "-"
  while true; do
    cur="${!value_key:-}"
    if [[ -n "$cur" ]]; then
      if [[ "$cur" != "-" ]]; then
        break
      fi
      # cur == "-" : only consider missing if RAWDEF was "-" (meaning "no default")
      if [[ "${!raw_default_key:-}" != "-" ]]; then
        break
      fi
    fi

    range="${!range_key:-}"
    def="${!default_key:-}"

    prompt="$name"
    if [[ -n "$range" && "$range" != "-" ]]; then
      prompt+=" ($range)"
    fi
    if [[ -n "$def" && "$def" != "-" ]]; then
      prompt+=" [$def]"
    fi
    prompt+=": "

    # Require a terminal only when a question is needed.
    if { exec 3<>/dev/tty; } 2>/dev/null; then
      printf '%s' "$prompt" >&3
      read -r input <&3 || exit 1
      exec 3>&-
    elif [[ -t 0 && -t 2 ]]; then
      printf '%s' "$prompt" >&2
      read -r input || exit 1
    else
      python3 "$(dirname "${BASH_SOURCE[0]}")/odev_messages.py" --error missing_required_flag -- "--$name"
      exit 1
    fi

    [[ -z "$input" && -n "$def" ]] && input="$def"
    [[ -z "$input" ]] && continue

    validate_value "$input" "$range" || continue
    printf -v "$value_key" '%s' "$input"
    break
  done
done

for p in ${PARAMS[@]+"${PARAMS[@]}"}; do
  IFS=',' read -r name _ <<< "$p"
  key="value_$name"
  if declare -p "$key" >/dev/null 2>&1; then
    printf '%s=%s\n' "$name" "${!key}"
  fi
done
