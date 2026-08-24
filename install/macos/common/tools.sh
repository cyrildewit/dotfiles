#!/usr/bin/env bash

# @file install/macos/common/tools.sh
# @brief Optional command-line tools.
# @description
#   Installs formulae that improve the shell but that nothing here requires.
#   Every consumer of these guards its own use, so a machine without them still
#   gets a working configuration.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly FORMULAE=(
    ccusage
    eza
    htop
    zsh-autosuggestions
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
        echo "Optional tools are already present."
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
