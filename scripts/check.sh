#!/bin/sh
# Hygiene check for tracked files: no em dash, no email address.
# Run it from the repository root before every commit:
#   scripts/check.sh
set -eu

status=0
files=$(git ls-files | grep -v '\.png$' || true)

dash=$(printf '\342\200\224')
if printf '%s\n' "$files" | xargs grep -n -- "$dash" 2>/dev/null; then
    echo "check: an em dash is in the files above." >&2
    status=1
fi

if printf '%s\n' "$files" | xargs grep -nE '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}' 2>/dev/null; then
    echo "check: an email address is in the files above." >&2
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "check: clean ($(printf '%s\n' "$files" | wc -l) files)."
fi
exit "$status"
