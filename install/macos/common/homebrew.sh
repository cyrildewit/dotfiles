#!/usr/bin/env bash

# @file install/macos/common/homebrew.sh
# @brief Bootstrap Homebrew on macOS.
# @description
#   Installs Homebrew when it is missing and puts the resulting brew on PATH so
#   later steps in the same script can use it.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

#
# @description Check whether brew is already available.
#
function is_homebrew_installed() {
    command -v brew &> /dev/null
}

#
# @description Print the Homebrew prefix for this architecture.
#
function homebrew_prefix() {
    if [ "$(uname -m)" = "arm64" ]; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

#
# @description Install Homebrew non-interactively when it is missing.
#
function install_homebrew() {
    if is_homebrew_installed; then
        return 0
    fi

    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

#
# @description Add brew to PATH for the remainder of this script.
#
function activate_homebrew() {
    local brew_bin
    brew_bin="$(homebrew_prefix)/bin/brew"

    if [ -x "${brew_bin}" ]; then
        eval "$("${brew_bin}" shellenv)"
    fi
}

#
# @description Ensure Homebrew is installed and usable.
#
function main() {
    install_homebrew
    activate_homebrew
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
