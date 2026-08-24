#!/usr/bin/env bash

# @file install/macos/common/homebrew.sh
# @brief Make sure Homebrew exists before anything else needs it.
# @description
#   Runs the upstream installer when brew is absent, then exports the resulting
#   environment so the rest of this run can call brew without a login shell.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

function is_homebrew_installed() {
    command -v brew &> /dev/null
}

function homebrew_prefix() {
    if [ "$(uname -m)" = "arm64" ]; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

function install_homebrew() {
    if is_homebrew_installed; then
        return 0
    fi

    NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

function activate_homebrew() {
    local brew_bin
    brew_bin="$(homebrew_prefix)/bin/brew"

    if [ -x "${brew_bin}" ]; then
        eval "$("${brew_bin}" shellenv)"
    fi
}

function main() {
    install_homebrew
    activate_homebrew
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
