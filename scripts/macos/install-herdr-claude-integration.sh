#!/usr/bin/env bash

# Install the herdr hook that reports Claude Code sessions to the herdr server.
# herdr owns the hook script and versions it, so this runs on every apply rather
# than once, and reinstalls whenever the installed version falls behind.
#
# Only the script is herdr's to write. The settings.json entry that calls it is
# templated alongside the rest of the Claude Code settings, because that file is
# chezmoi's and an apply would otherwise revert whatever herdr wrote into it.
# Reinstalling leaves an entry that is already there alone, so the two agree.

set -Eeuo pipefail

readonly INTEGRATION="claude"

if ! command -v herdr > /dev/null 2>&1; then
    echo "run_after_45-install-herdr-claude-integration: herdr is not installed, skipping" >&2
    exit 0
fi

# Anything other than "current" is worth reinstalling: not installed on a new
# machine, outdated after a herdr update, and an unreadable state if the output
# ever changes shape, which costs a reinstall that would have been a no-op.
state="$(herdr integration status | awk -F': ' -v target="${INTEGRATION}" '$1 == target { print $2 }')"

case "${state}" in
    current*)
        exit 0
        ;;
esac

herdr integration install "${INTEGRATION}"
