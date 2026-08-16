#!/usr/bin/env bash

# @file setup.sh
# @brief Bring a new machine to the point where chezmoi can take over.
# @description
#   Gets a package manager and chezmoi onto the machine, then hands over to
#   `chezmoi init --apply`, which clones this repository and runs everything
#   under `install/`. Running it again on a machine that is already set up is a
#   no-op.
#
#   Only the part that acquires chezmoi differs per operating system, so that
#   is the only thing behind `bootstrap_os`. Everything after it is shared.
#   Adding Linux means writing `bootstrap_linux` and giving it a branch.
#
#   Windows does not belong in this file. A machine without bash cannot run it
#   at all, so native Windows needs its own `setup.ps1`; the branch here only
#   catches someone reaching this script from Git Bash or MSYS and points them
#   at it.
#
#   The Homebrew steps repeat `install/macos/common/homebrew.sh`. That is not
#   worth avoiding: this script has to work on a machine where the repository
#   has not been cloned yet, so it cannot include anything from it.
#
#   Bootstrap a machine with:
#
#     bash -c "$(curl -fsLS https://raw.githubusercontent.com/cyrildewit/dotfiles/main/setup.sh)"

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

readonly DOTFILES_REPO_URL="${DOTFILES_REPO_URL:-https://github.com/cyrildewit/dotfiles.git}"
readonly HOMEBREW_INSTALLER_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

#
# @description Print the kernel name this machine reports.
#   Git Bash and MSYS answer `MINGW64_NT-...` and `MSYS_NT-...`, which is how
#   a Windows host reaches this script at all.
# @stdout The kernel name.
#
function get_os_type() {
    uname -s
}

#
# @description Report whether a terminal is attached.
#   chezmoi reads its prompts from /dev/tty, which CI does not have.
#
function is_tty() {
    [ -t 0 ]
}

#
# @description Check whether brew is already available.
#
function is_homebrew_installed() {
    command -v brew &> /dev/null
}

#
# @description Print the Homebrew prefix for this architecture.
#
function homebrew_prefix() {
    if [ "$(uname -m)" = "arm64" ]; then
        echo "/opt/homebrew"
    else
        echo "/usr/local"
    fi
}

#
# @description Install Homebrew non-interactively when it is missing.
#   The upstream installer pulls in the Command Line Tools on its own, so
#   nothing here has to ask for them first.
#
function install_homebrew() {
    if is_homebrew_installed; then
        return 0
    fi

    echo "Installing Homebrew."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "${HOMEBREW_INSTALLER_URL}")"
}

#
# @description Add brew to PATH for the remainder of this script.
#
function activate_homebrew() {
    local brew_bin
    brew_bin="$(homebrew_prefix)/bin/brew"

    if [ -x "${brew_bin}" ]; then
        eval "$("${brew_bin}" shellenv)"
    fi
}

#
# @description Install chezmoi through Homebrew.
#   Deliberately not the standalone installer: that leaves a binary in
#   ~/.local/bin that nothing maintains afterwards. `dependencies.sh` lists the
#   same formula, so the two agree about who owns it.
#
#   This is the macOS answer only. Homebrew is not how the other systems will
#   get chezmoi, which is why it sits behind `bootstrap_macos` rather than in
#   `main`.
#
function install_chezmoi_with_homebrew() {
    if brew list --formula chezmoi &> /dev/null; then
        return 0
    fi

    echo "Installing chezmoi."
    brew install chezmoi
}

#
# @description Get Homebrew and chezmoi onto a macOS machine.
#
function bootstrap_macos() {
    install_homebrew
    activate_homebrew
    install_chezmoi_with_homebrew
}

#
# @description Refuse an operating system nothing has been written for yet.
# @arg $1 string The kernel name that was found.
# @exitcode 1 Always.
#
function unsupported_os() {
    echo "No bootstrap has been written for $1 yet." >&2
    exit 1
}

#
# @description Send a Windows host to the bootstrap that can actually run.
#   Reachable only from Git Bash or MSYS; a plain Windows machine never gets
#   far enough to execute this file.
# @exitcode 1 Always.
#
function redirect_to_powershell() {
    echo "Windows is bootstrapped by setup.ps1, not this script." >&2
    exit 1
}

#
# @description Run the bootstrap that suits this machine.
#   Add an operating system by writing its `bootstrap_*` function and giving it
#   a branch here. Nothing outside this function should need to change.
#
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
# @description Clone the repository and apply it.
#   `init` prompts for the machine type and the optional toolchains, then
#   `--apply` runs the install scripts.
#
function apply_dotfiles() {
    local options=()

    if ! is_tty; then
        options+=(--no-tty)
    fi

    echo "Applying ${DOTFILES_REPO_URL}."
    chezmoi init --apply "${DOTFILES_REPO_URL}" ${options[@]+"${options[@]}"}
}

#
# @description Bootstrap this machine.
#
function main() {
    bootstrap_os
    apply_dotfiles
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
