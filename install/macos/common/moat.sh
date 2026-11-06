#!/usr/bin/env bash

# @file install/macos/common/moat.sh
# @brief Install Moat, Laravel's read-only GitHub security auditor.
# @description
#   Moat ships from a tap inside its own repository rather than a
#   homebrew-<name> repository, so the tap needs an explicit URL. Homebrew also
#   refuses packages from a tap until it is trusted. Both steps happen here,
#   which is why this is not just another entry in the formula list.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly TAP="laravel/moat"
readonly TAP_URL="https://github.com/laravel/moat"
readonly FORMULA="laravel/moat/moat"

#
# @description CI resolves the formula rather than installing it. The tap and
#   the trust still happen, since without them there is nothing to resolve
#   against.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

#
# @description Checked directly rather than through brew, which refuses to
#   answer questions about an untrusted tap.
#
function has_moat() {
    command -v moat &> /dev/null
}

function add_tap() {
    if brew tap | grep --fixed-strings --line-regexp --quiet "${TAP}"; then
        return 0
    fi

    brew tap "${TAP}" "${TAP_URL}"
}

#
# @description Whole-tap trust would cover everything Laravel publishes there
#   later too.
#
function trust_formula() {
    brew trust --formula "${FORMULA}"
}

function install_moat() {
    if has_moat; then
        echo "moat is already installed."
        return 0
    fi

    add_tap
    trust_formula

    if is_ci; then
        echo "Resolving ${FORMULA}."
        brew info --formula "${FORMULA}" > /dev/null
        return 0
    fi

    brew install --formula "${FORMULA}"
}

function main() {
    install_moat
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
