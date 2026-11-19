#!/bin/bash

logged_in="0"

# Run gh auth status and capture the output.
auth_status=$(GH_PROMPT_DISABLED=1 "${1:-gh}" auth status --hostname github.com 2>&1)

# Use the same login marker as Odev.
if grep -q "✓ Logged in to github.com" <<< "$auth_status"; then
  logged_in="1"
fi

echo "$logged_in"
