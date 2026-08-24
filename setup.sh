#!/usr/bin/env bash

# @file setup.sh
# @brief Bring a new machine to the point where chezmoi can take over.
# @description
#   Gets a package manager and chezmoi onto the machine, then hands over to
#   `chezmoi init --apply`, which clones this repository and runs everything
#   under `install/`. Running it again on a machine that is already set up is a
#   no-op.
#
#   Bootstrap a machine with:
#
#     bash -c "$(curl -fsLS https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.sh)"

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-git@github.com:cyrildewit/dotfiles.git}"
readonly DOTFILES_BRANCH="${DOTFILES_BRANCH:-}"
readonly HOMEBREW_INSTALLER_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

#
# @description Git Bash and MSYS answer `MINGW64_NT-...` and `MSYS_NT-...`,
#   which is how a Windows host reaches this script at all.
#
function get_os_type() {
    uname -s
}

#
# @description chezmoi reads its prompts from /dev/tty, which CI does not have.
#
function is_tty() {
    [ -t 0 ]
}

function is_homebrew_installed() {
    command -v brew &> /dev/null
}

function homebrew_prefix() {
    if [ "$(uname -m)" = "arm64" ]; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

#
# @description The upstream installer pulls in the Command Line Tools on its
#   own, so nothing here has to ask for them first.
#
function install_homebrew() {
    if is_homebrew_installed; then
        return 0
    fi

    echo "Installing Homebrew."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "${HOMEBREW_INSTALLER_URL}")"
}

function activate_homebrew() {
    local brew_bin
    brew_bin="$(homebrew_prefix)/bin/brew"

    if [ -x "${brew_bin}" ]; then
        eval "$("${brew_bin}" shellenv)"
    fi
}

function install_chezmoi_with_homebrew() {
    if brew list --formula chezmoi &> /dev/null; then
        return 0
    fi

    echo "Installing chezmoi."
    brew install chezmoi
}

function bootstrap_macos() {
    install_homebrew
    activate_homebrew
    install_chezmoi_with_homebrew
}

function unsupported_os() {
    echo "No bootstrap has been written for $1 yet." >&2
    exit 1
}

#
# @description Reachable only from Git Bash or MSYS; a plain Windows machine
#   never gets far enough to execute this file.
#
function redirect_to_powershell() {
    echo "Windows is bootstrapped by setup.ps1, not this script." >&2
    exit 1
}

function bootstrap_os() {
    local os_type
    os_type="$(get_os_type)"

    case "${os_type}" in
        Darwin) bootstrap_macos ;;
        MINGW* | MSYS* | CYGWIN*) redirect_to_powershell ;;
        *) unsupported_os "${os_type}" ;;
    esac
}

#
# @description Without a terminal chezmoi reads its answers from stdin, which
#   is how CI drives the prompts.
#
function apply_dotfiles() {
    local options=()

    if ! is_tty; then
        options+=(--no-tty)
    fi

    if [ -n "${DOTFILES_BRANCH}" ]; then
        options+=(--branch "${DOTFILES_BRANCH}")
    fi

    echo "Applying ${DOTFILES_REPO_URL}."
    chezmoi init --apply "${DOTFILES_REPO_URL}" ${options[@]+"${options[@]}"}
}

function main() {
    bootstrap_os
    apply_dotfiles
}

# `bash -c "$(curl ...)"` leaves BASH_SOURCE empty, which `set -u` treats as an
# unbound variable. Falling back to $0 keeps that path working while still
# staying quiet when the file is sourced, as the tests do.
if [[ "${BASH_SOURCE[0]:-$0}" == "${0}" ]]; then
    main
fi
