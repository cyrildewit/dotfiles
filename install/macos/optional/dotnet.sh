#!/usr/bin/env bash

# @file install/macos/optional/dotnet.sh
# @brief The .NET toolchain, for machines that opted in.
# @description
#   Installs the .NET SDK and the Aspire CLI. Aspire ships from a Microsoft tap
#   rather than homebrew-core, and Homebrew refuses packages from a tap until it
#   is trusted, so the tap and the trust happen here too.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly SDK_FORMULA="dotnet"
readonly ASPIRE_TAP="microsoft/aspire"
readonly ASPIRE_CASK="microsoft/aspire/aspire"

#
# @description CI resolves the packages rather than installing them. The tap
#   and the trust still happen, since without them there is nothing to resolve
#   against.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

function has_formula() {
    brew list --formula "$1" &> /dev/null
}

function has_cask() {
    brew list --cask "$1" &> /dev/null
}

function install_sdk() {
    if has_formula "${SDK_FORMULA}"; then
        echo "The .NET SDK is already installed."
        return 0
    fi

    if is_ci; then
        echo "Resolving ${SDK_FORMULA}."
        brew info "${SDK_FORMULA}" > /dev/null
        return 0
    fi

    echo "Installing ${SDK_FORMULA}."
    brew install "${SDK_FORMULA}"
}

function add_tap() {
    if brew tap | grep --fixed-strings --line-regexp --quiet "${ASPIRE_TAP}"; then
        return 0
    fi

    brew tap "${ASPIRE_TAP}"
}

#
# @description Whole-tap trust would cover everything Microsoft publishes
#   there later too.
#
function trust_cask() {
    brew trust --cask "${ASPIRE_CASK}"
}

function install_aspire() {
    if has_cask "${ASPIRE_CASK}"; then
        echo "The Aspire CLI is already installed."
        return 0
    fi

    add_tap
    trust_cask

    if is_ci; then
        echo "Resolving ${ASPIRE_CASK}."
        brew info --cask "${ASPIRE_CASK}" > /dev/null
        return 0
    fi

    echo "Installing ${ASPIRE_CASK}."
    brew install --cask "${ASPIRE_CASK}"
}

function main() {
    install_sdk
    install_aspire
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
