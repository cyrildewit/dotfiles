#!/usr/bin/env bash

# @file install/macos/common/fonts.sh
# @brief Fonts the configuration asks for by name.
# @description
#   Installs the font casks that other configuration in this repository refers
#   to. A missing font is not an error anywhere, it just leaves an application
#   silently falling back to a default.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly FONT_CASKS=(
    font-jetbrains-mono-nerd-font
)

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

function install_fonts() {
    local pending=()
    local cask

    for cask in "${FONT_CASKS[@]}"; do
        has_cask "${cask}" || pending+=("${cask}")
    done

    if [[ ${#pending[@]} -eq 0 ]]; then
        echo "Fonts are already installed."
        return 0
    fi

    if is_ci; then
        echo "Resolving: ${pending[*]}"
        brew info --cask "${pending[@]}" > /dev/null
        return 0
    fi

    echo "Installing: ${pending[*]}"
    brew install --cask "${pending[@]}"
}

function main() {
    install_fonts
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
