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
    htop
    zsh-autosuggestions
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

#
# @description Ensure the optional tools are installed.
#
function main() {
    install_missing_formulae
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
