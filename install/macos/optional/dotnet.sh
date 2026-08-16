#!/usr/bin/env bash

# @file install/macos/optional/dotnet.sh
# @brief The .NET toolchain, for machines that opted in.
# @description
#   Installs the .NET SDK and the Aspire CLI. Aspire ships from a Microsoft tap
#   rather than homebrew-core, and Homebrew refuses packages from a tap until it
#   is trusted, so the tap and the trust happen here too.
#
#   Together these are close to a gigabyte, which is why `chezmoi init` asks
#   before any of it runs. The shim including this file owns that decision.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly SDK_FORMULA="dotnet"
readonly ASPIRE_TAP="microsoft/aspire"
readonly ASPIRE_CASK="microsoft/aspire/aspire"

#
# @description Report whether a formula is already present locally.
# @arg $1 string Formula name.
# @exitcode 0 If the formula is installed.
#
function has_formula() {
    brew list --formula "$1" &> /dev/null
}

#
# @description Report whether Homebrew already manages a cask.
# @arg $1 string Cask token.
# @exitcode 0 If the cask is installed.
#
function has_cask() {
    brew list --cask "$1" &> /dev/null
}

#
# @description Install the .NET SDK from homebrew-core.
#
function install_sdk() {
    if has_formula "${SDK_FORMULA}"; then
        echo "The .NET SDK is already installed."
        return 0
    fi

    echo "Installing ${SDK_FORMULA}."
    brew install "${SDK_FORMULA}"
}

#
# @description Add the Microsoft tap when it is not configured yet.
#
function add_tap() {
    if brew tap | grep --fixed-strings --line-regexp --quiet "${ASPIRE_TAP}"; then
        return 0
    fi

    brew tap "${ASPIRE_TAP}"
}

#
# @description Trust the single cask, not the whole tap.
#   Whole-tap trust would cover everything Microsoft publishes there later too.
#
function trust_cask() {
    brew trust --cask "${ASPIRE_CASK}"
}

#
# @description Install the Aspire CLI from the Microsoft tap.
#
function install_aspire() {
    if has_cask "${ASPIRE_CASK}"; then
        echo "The Aspire CLI is already installed."
        return 0
    fi

    add_tap
    trust_cask

    echo "Installing ${ASPIRE_CASK}."
    brew install --cask "${ASPIRE_CASK}"
}

#
# @description Ensure the .NET toolchain is installed.
#
function main() {
    install_sdk
    install_aspire
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
