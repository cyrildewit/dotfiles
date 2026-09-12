#!/usr/bin/env bash

# @file install/macos/common/herdr_server.sh
# @brief Run the herdr server from login onwards.
# @description
#   Registers the launchd job the herdr formula ships, so the server that owns
#   the agent terminals is up before a client asks for it. The formula itself is
#   an entry in the tools list; only the service belongs here.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly FORMULA="herdr"

#
# @description The runner is discarded when the job ends, so a login service on
#   it has nothing to serve.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

function has_formula() {
    brew list --formula "${FORMULA}" &> /dev/null
}

#
# @description Starting a started service is harmless but noisy, and the status
#   column in `brew services list` answers the question first.
#
function is_started() {
    local status

    status="$(brew services list | awk -v formula="${FORMULA}" '$1 == formula { print $2 }')"

    [ "${status}" = "started" ]
}

function start_herdr_server() {
    if is_ci; then
        echo "Skipping the herdr server: this is a CI run."
        return 0
    fi

    if ! has_formula; then
        echo "Skipping the herdr server: ${FORMULA} is not installed."
        return 0
    fi

    if is_started; then
        echo "The herdr server is already running."
        return 0
    fi

    echo "Starting the herdr server."
    brew services start "${FORMULA}"
}

function main() {
    start_herdr_server
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
