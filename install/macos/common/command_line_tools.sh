#!/usr/bin/env bash

# @file install/macos/common/command_line_tools.sh
# @brief Install the Xcode Command Line Tools on macOS.
# @description
#   Triggers the Command Line Tools installer when no developer directory is
#   active, then waits for it to finish. The installer runs in its own GUI
#   dialog, so this script polls instead of returning early.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly WAIT_TIMEOUT_SECONDS=1800
readonly WAIT_INTERVAL_SECONDS=5

#
# @description Check whether an active developer directory is set, which covers
#   both the Command Line Tools and a full Xcode install.
#
function is_command_line_tools_installed() {
    xcode-select --print-path &> /dev/null
}

#
# @description Ask macOS to install the Command Line Tools.
#   Exits non-zero when they are already present or an install is in progress,
#   neither of which is an error here.
#
function request_command_line_tools() {
    xcode-select --install &> /dev/null || true
}

#
# @description Block until the Command Line Tools appear or the timeout passes.
# @exitcode 1 If the installer did not finish in time.
#
function wait_for_command_line_tools() {
    local waited=0

    while ! is_command_line_tools_installed; do
        if [ "${waited}" -ge "${WAIT_TIMEOUT_SECONDS}" ]; then
            echo "Command Line Tools were not installed within ${WAIT_TIMEOUT_SECONDS}s." >&2
            return 1
        fi

        sleep "${WAIT_INTERVAL_SECONDS}"
        waited=$((waited + WAIT_INTERVAL_SECONDS))
    done
}

#
# @description Ensure the Command Line Tools are installed.
#
function main() {
    if is_command_line_tools_installed; then
        return 0
    fi

    echo "Installing the Command Line Tools. Complete the dialog that just opened."
    request_command_line_tools
    wait_for_command_line_tools
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
