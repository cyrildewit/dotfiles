#!/usr/bin/env bash

# @file install/macos/common/defaults.sh
# @brief System preferences a fresh machine does not come with.
# @description
#   Writes the `defaults` domains this setup expects, so a new Mac behaves like
#   the last one without a pass through System Settings.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

#
# @description The runner is discarded when the job ends, so changing its
#   preferences buys nothing, and some domains refuse the write regardless.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

#
# @description `defaults write` updates the plist either way, but a running app
#   keeps serving the copy it read on startup.
#
function restart_applications() {
    local app

    for app in "$@"; do
        killall "${app}" 2> /dev/null || echo "Skipping ${app}: it was not running."
    done
}

function defaults_ui() {
    # Show the battery charge as a number, not just the icon
    defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
}

function defaults_trackpad() {
    # Tap to click, for this user and for the login screen
    defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

    # Drag a window with three fingers instead of holding the click down.
    # System Settings files this under Accessibility, not Trackpad.
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
}

function main() {
    if is_ci; then
        echo "Skipping the macOS defaults: this is a CI run."
        return 0
    fi

    defaults_ui
    defaults_trackpad

    restart_applications ControlCenter SystemUIServer
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
