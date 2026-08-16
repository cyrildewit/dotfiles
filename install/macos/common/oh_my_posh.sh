#!/usr/bin/env bash

# @file install/macos/common/oh_my_posh.sh
# @brief Install the prompt the shell configuration initialises.
# @description
#   oh-my-posh ships from its author's own tap rather than homebrew-core, and
#   Homebrew refuses packages from a tap until it is trusted. Both steps happen
#   here, which is why this is not just another entry in the formula list.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly TAP="jandedobbeleer/oh-my-posh"
readonly FORMULA="jandedobbeleer/oh-my-posh/oh-my-posh"

#
# @description Report whether this is a continuous integration run.
#   CI resolves the formula rather than installing it. The tap and the trust
#   still happen, since without them there is nothing to resolve against.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

#
# @description Report whether the prompt is already on PATH.
#   Checked directly rather than through brew, which refuses to answer
#   questions about an untrusted tap.
#
function has_oh_my_posh() {
    command -v oh-my-posh &> /dev/null
}

#
# @description Add the author's tap when it is not configured yet.
#
function add_tap() {
    if brew tap | grep --fixed-strings --line-regexp --quiet "${TAP}"; then
        return 0
    fi

    brew tap "${TAP}"
}

#
# @description Trust the single formula, not the whole tap.
#   Whole-tap trust would cover everything the author publishes later too.
#
function trust_formula() {
    brew trust --formula "${FORMULA}"
}

#
# @description Install oh-my-posh from the tap.
#
function install_oh_my_posh() {
    if has_oh_my_posh; then
        echo "oh-my-posh is already installed."
        return 0
    fi

    add_tap
    trust_formula

    if is_ci; then
        echo "Resolving ${FORMULA}."
        brew info "${FORMULA}" > /dev/null
        return 0
    fi

    brew install "${FORMULA}"
}

#
# @description Ensure the prompt is installed.
#
function main() {
    install_oh_my_posh
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
