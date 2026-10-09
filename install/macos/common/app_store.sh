#!/usr/bin/env bash

# @file install/macos/common/app_store.sh
# @brief Applications only distributed through the Mac App Store.
# @description
#   Installs `mas` and uses it to get the apps that have no Homebrew cask. The
#   App Store needs a signed-in Apple Account, which cannot be scripted, so an
#   app that fails to install is reported and left for a manual install rather
#   than failing the whole bootstrap.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

# App Store ID and bundle name pairs; macOS ships a bash without associative
# arrays.
readonly APPS=(
    "937984704:Amphetamine"
)

#
# @description CI resolves `mas` rather than installing it, and never reaches
#   the App Store, which has no account signed in there.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

function install_mas() {
    if brew list --formula mas &> /dev/null; then
        return 0
    fi

    if is_ci; then
        echo "Resolving mas."
        brew info --formula mas > /dev/null
        return 0
    fi

    echo "Installing mas."
    brew install mas
}

function install_app() {
    local id="$1"
    local name="$2"

    if [ -d "/Applications/${name}.app" ]; then
        return 0
    fi

    echo "Installing ${name}."

    if ! mas get "${id}"; then
        echo "Could not install ${name}: sign in to the App Store and install it from there." >&2
    fi
}

function install_applications() {
    local app

    for app in "${APPS[@]}"; do
        install_app "${app%%:*}" "${app#*:}"
    done
}

function main() {
    install_mas

    if is_ci; then
        return 0
    fi

    install_applications
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
