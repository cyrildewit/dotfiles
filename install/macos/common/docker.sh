#!/usr/bin/env bash

# @file install/macos/common/docker.sh
# @brief Install Docker Desktop when the machine has none.
# @description
#   Installs the Docker Desktop cask on a machine without it. An existing app
#   bundle is left alone, whoever put it there: the cask auto-updates, so
#   handing it to Homebrew buys nothing worth a full re-download.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly CASK="docker-desktop"
readonly APP_PATH="/Applications/Docker.app"

#
# @description Report whether this is a continuous integration run.
#   CI resolves the cask rather than installing it. That still catches a
#   renamed or misspelled token without paying for the download.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

#
# @description Report whether Homebrew already manages the cask.
# @exitcode 0 If the cask is installed.
#
function has_cask() {
    brew list --cask "${CASK}" &> /dev/null
}

#
# @description Install Docker Desktop unless some copy of it is already here.
#
function install_docker() {
    if has_cask; then
        echo "Docker Desktop is already managed by Homebrew."
        return 0
    fi

    if [ -d "${APP_PATH}" ]; then
        echo "Docker Desktop is already installed at ${APP_PATH}."
        return 0
    fi

    if is_ci; then
        echo "Resolving ${CASK}."
        brew info --cask "${CASK}" > /dev/null
        return 0
    fi

    brew install --cask "${CASK}"
}

#
# @description Ensure Docker Desktop is installed.
#
function main() {
    install_docker
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
