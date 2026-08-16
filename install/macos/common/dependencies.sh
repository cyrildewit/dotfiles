#!/usr/bin/env bash

# @file install/macos/common/dependencies.sh
# @brief Core Homebrew formulae these dotfiles rely on.
# @description
#   Installs the command-line formulae the shell configuration expects to be
#   present. Anything that needs a tap, a cask, or post-install setup gets its
#   own script rather than a line here.
#
#   `chezmoi` is listed even though it is what runs this script: a machine
#   bootstrapped with the standalone installer has a binary nobody maintains,
#   and this hands it to Homebrew so `brew upgrade` keeps it current.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly FORMULAE=(
    chezmoi
    gh
    git
    zsh
)

#
# @description Report whether this is a continuous integration run.
#   CI resolves packages rather than installing them. That still catches a
#   renamed or misspelled token without paying for the download.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

#
# @description Report whether a formula is already present locally.
# @arg $1 string Formula name.
# @exitcode 0 If the formula is installed.
#
function has_formula() {
    brew list --formula "$1" &> /dev/null
}

#
# @description Install whichever entries of `FORMULAE` are still missing,
#   batched into a single brew invocation.
#
function install_missing_formulae() {
    local pending=()
    local formula

    for formula in "${FORMULAE[@]}"; do
        has_formula "${formula}" || pending+=("${formula}")
    done

    if [[ ${#pending[@]} -eq 0 ]]; then
        echo "Homebrew dependencies are already present."
        return 0
    fi

    if is_ci; then
        echo "Resolving: ${pending[*]}"
        brew info "${pending[@]}" > /dev/null
        return 0
    fi

    echo "Installing: ${pending[*]}"
    brew install "${pending[@]}"
}

#
# @description Ensure the Homebrew dependencies are installed.
#
function main() {
    install_missing_formulae
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
