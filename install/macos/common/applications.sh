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
    spotify
    todoist-app
    visual-studio-code
)

#
# @description Print where a cask puts its app bundle, if it has one.
#   Casks without an entry here install no bundle a manual copy could clash
#   with, so an empty result means "let brew decide".
# @arg $1 string Cask token.
# @stdout Absolute path, or nothing.
#
function bundle_path_for() {
    case "$1" in
        1password) echo "/Applications/1Password.app" ;;
        betterdisplay) echo "/Applications/BetterDisplay.app" ;;
        brave-browser) echo "/Applications/Brave Browser.app" ;;
        ghostty) echo "/Applications/Ghostty.app" ;;
        logi-options+) echo "/Applications/logioptionsplus.app" ;;
        macsyzones) echo "/Applications/MacsyZones.app" ;;
        spotify) echo "/Applications/Spotify.app" ;;
        todoist-app) echo "/Applications/Todoist.app" ;;
        *) echo "" ;;
    esac
}

#
# @description Report whether Homebrew already manages a cask.
# @arg $1 string Cask token.
#
function has_cask() {
    brew list --cask "$1" &> /dev/null
}

#
# @description Install a single cask unless it, or its app bundle, is present.
# @arg $1 string Cask token.
#
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

    echo "Installing ${cask}."
    brew install --cask "${cask}"
}

#
# @description Install every cask in `CASKS` that is still missing.
#
function install_applications() {
    local cask

    for cask in "${CASKS[@]}"; do
        install_cask "${cask}"
    done
}

#
# @description Ensure the expected applications are installed.
#
function main() {
    install_applications
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
