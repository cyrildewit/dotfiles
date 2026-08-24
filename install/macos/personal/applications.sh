#!/usr/bin/env bash

# @file install/macos/personal/applications.sh
# @brief Applications that belong on a personal machine only.
# @description
#   Installs the casks that have no place on a work machine.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly CASKS=(
    proton-drive
    proton-mail
    proton-pass
)

function bundle_path_for() {
    case "$1" in
        proton-drive) echo "/Applications/Proton Drive.app" ;;
        proton-mail) echo "/Applications/Proton Mail.app" ;;
        proton-pass) echo "/Applications/Proton Pass.app" ;;
        *) echo "" ;;
    esac
}

#
# @description CI resolves casks rather than installing them: enough to catch
#   a renamed token without paying for the download.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

function has_cask() {
    brew list --cask "$1" &> /dev/null
}

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

    if is_ci; then
        echo "Resolving ${cask}."
        brew info --cask "${cask}" > /dev/null
        return 0
    fi

    echo "Installing ${cask}."
    brew install --cask "${cask}"
}

function install_applications() {
    local cask

    for cask in "${CASKS[@]}"; do
        install_cask "${cask}"
    done
}

function main() {
    install_applications
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
