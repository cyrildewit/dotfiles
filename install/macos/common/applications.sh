#!/usr/bin/env bash

# @file install/macos/common/applications.sh
# @brief Applications the dotfiles expect to find.
# @description
#   Installs the casks referenced by the configuration in this repository. An
#   app bundle that is already in place is left alone, since replacing one only
#   costs a download and these all update themselves.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly CASKS=(
    1password
    1password-cli
    betterdisplay
    brave-browser
    claude
    claude-code
    ghostty
    jetbrains-toolbox
    logi-options+
    macsyzones
    obsidian
    spotify
    todoist-app
    visual-studio-code
)

#
# @description Casks without an entry here install no bundle a manual copy
#   could clash with, so an empty result means "let brew decide".
#
function bundle_path_for() {
    case "$1" in
        1password) echo "/Applications/1Password.app" ;;
        betterdisplay) echo "/Applications/BetterDisplay.app" ;;
        brave-browser) echo "/Applications/Brave Browser.app" ;;
        ghostty) echo "/Applications/Ghostty.app" ;;
        logi-options+) echo "/Applications/logioptionsplus.app" ;;
        macsyzones) echo "/Applications/MacsyZones.app" ;;
        obsidian) echo "/Applications/Obsidian.app" ;;
        spotify) echo "/Applications/Spotify.app" ;;
        todoist-app) echo "/Applications/Todoist.app" ;;
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
