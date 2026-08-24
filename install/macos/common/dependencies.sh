#!/usr/bin/env bash

# @file install/macos/common/dependencies.sh
# @brief Core Homebrew formulae these dotfiles rely on.
# @description
#   Installs the command-line formulae the shell configuration expects to be
#   present. Anything that needs a tap, a cask, or post-install setup gets its
#   own script rather than a line here.

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
# @description CI resolves packages rather than installing them: enough to
#   catch a renamed token without paying for the download.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

function has_formula() {
    brew list --formula "$1" &> /dev/null
}

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

function main() {
    install_missing_formulae
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
