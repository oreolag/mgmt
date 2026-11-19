#!/bin/bash
set -euo pipefail

CLI_PATH="$1"
constant_name="$2"

constant_value="$(cat "$CLI_PATH/src/$constant_name")"
constant_value="${constant_value#\'}"
constant_value="${constant_value%\'}"
printf '%s\n' "$constant_value"
