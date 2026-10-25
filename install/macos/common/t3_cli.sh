#!/usr/bin/env bash

# @file install/macos/common/t3_cli.sh
# @brief Install the T3 Code CLI, the server half of T3 Code without the app.
# @description
#   The t3-code cask in applications.sh already carries a server. The CLI adds
#   `t3 serve`, `t3 connect` and `t3 service install`, which keep the agents
#   reachable from other devices without the desktop app open.
#
#   No package manager carries the CLI, so this runs T3's own installer. The
#   installer puts `t3` in ~/.local/bin, which dot_zprofile.tmpl adds to PATH,
#   and `t3 update` replaces it in place. The installer is downloaded to a file
#   and run as a child process, so its `exit` ends the installer and not this
#   script.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly INSTALLER_URL="https://t3.codes/install.sh"
readonly BIN="${HOME}/.local/bin/t3"

installer=""

#
# @description CI fetches the installer rather than running it: enough to
#   catch a moved URL without paying for the download.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

function has_t3() {
    [ -x "${BIN}" ] || command -v t3 &> /dev/null
}

#
# @description T3 publishes no CLI build for Intel Macs, so the installer
#   would fail on one. The desktop app still covers that machine.
#
function is_supported_arch() {
    [ "$(uname -m)" = "arm64" ]
}

function install_t3_cli() {
    if has_t3; then
        echo "t3 is already installed."
        return 0
    fi

    if ! is_supported_arch; then
        echo "Skipping t3: there is no CLI build for $(uname -m)."
        return 0
    fi

    installer="$(mktemp)"
    trap 'rm -f "${installer}"' EXIT

    curl -fsSL "${INSTALLER_URL}" -o "${installer}"

    if is_ci; then
        echo "Resolved ${INSTALLER_URL}."
        return 0
    fi

    echo "Installing t3."
    sh "${installer}"
}

function main() {
    install_t3_cli
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
