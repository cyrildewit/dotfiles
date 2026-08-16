#!/usr/bin/env bash

# @file install/macos/personal/applications.sh
# @brief Applications that belong on a personal machine only.
# @description
#   Installs the casks that have no place on a work machine. The shim including
#   this file is what decides whether it runs at all, so nothing here needs to
#   ask which machine it is on.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly CASKS=(
    proton-drive
    proton-mail
    proton-pass
)

#
# @description Print where a cask puts its app bundle, if it has one.
# @arg $1 string Cask token.
# @stdout Absolute path, or nothing.
#
function bundle_path_for() {
    case "$1" in
        proton-drive) echo "/Applications/Proton Drive.app" ;;
        proton-mail) echo "/Applications/Proton Mail.app" ;;
        proton-pass) echo "/Applications/Proton Pass.app" ;;
        *) echo "" ;;
    esac
}

#
# @description Report whether Homebrew already manages a cask.
# @arg $1 string Cask token.
#
function has_cask() {
    brew list --cask "$1" &> /dev/null
}

#
# @description Install a single cask unless it, or its app bundle, is present.
# @arg $1 string Cask token.
#
function install_cask() {
    local cask="$1"
    local bundle

    if has_cask "${cask}"; then
        return 0
    fi

    bundle="$(bundle_path_for "${cask}")"

    if [ -n "${bundle}" ] && [ -d "${bundle}" ]; then
        echo "Skipping ${cask}: ${bundle} is already installed."
        return 0
    fi

    echo "Installing ${cask}."
    brew install --cask "${cask}"
}

#
# @description Install every cask in `CASKS` that is still missing.
#
function install_applications() {
    local cask

    for cask in "${CASKS[@]}"; do
        install_cask "${cask}"
    done
}

#
# @description Ensure the personal applications are installed.
#
function main() {
    install_applications
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
