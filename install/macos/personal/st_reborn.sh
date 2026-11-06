#!/usr/bin/env bash

# @file install/macos/personal/st_reborn.sh
# @brief Install ST Reborn, the cloud-free controller for Bose SoundTouch.
# @description
#   ST Reborn ships from its author's tap rather than homebrew-cask, and
#   Homebrew refuses packages from a tap until it is trusted, so the tap and
#   the trust happen here too.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly TAP="jrpersonal/tap"
readonly CASK="jrpersonal/tap/st-reborn"
readonly BUNDLE="/Applications/ST Reborn.app"

#
# @description CI resolves the cask rather than installing it. The tap and the
#   trust still happen, since without them there is nothing to resolve against.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

#
# @description Checked through the bundle rather than brew, which refuses to
#   answer questions about an untrusted tap.
#
function has_st_reborn() {
    [ -d "${BUNDLE}" ]
}

function add_tap() {
    if brew tap | grep --fixed-strings --line-regexp --quiet "${TAP}"; then
        return 0
    fi

    brew tap "${TAP}"
}

#
# @description Whole-tap trust would cover everything the author publishes
#   there later too.
#
function trust_cask() {
    brew trust --cask "${CASK}"
}

function install_st_reborn() {
    if has_st_reborn; then
        echo "ST Reborn is already installed."
        return 0
    fi

    add_tap
    trust_cask

    if is_ci; then
        echo "Resolving ${CASK}."
        brew info --cask "${CASK}" > /dev/null
        return 0
    fi

    echo "Installing ${CASK}."
    brew install --cask "${CASK}"
}

function main() {
    install_st_reborn
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
