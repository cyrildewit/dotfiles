#!/usr/bin/env bash

# @file install/macos/common/defaults.sh
# @brief System preferences a fresh machine does not come with.
# @description
#   Writes the `defaults` domains this setup expects, so a new Mac behaves like
#   the last one without a pass through System Settings. Each area gets its own
#   `defaults_*` function, so a preference can be changed or dropped without
#   disturbing the rest, and `main` decides what actually runs.
#
#   To add a preference, write a `defaults_<area>` function, call it from
#   `main`, and name the applications that need a restart afterwards.

set -Eeuo pipefail

if [ "${DOTFILES_DEBUG:-}" ]; then
    set -x
fi

#
# @description Report whether this is a continuous integration run.
#   The runner is discarded when the job ends, so changing its preferences buys
#   nothing, and some domains refuse the write there regardless.
#
function is_ci() {
    [ "${CI:-false}" = "true" ]
}

#
# @description Restart the applications that read their preferences once, at
#   launch. `defaults write` updates the plist either way, but a running app
#   keeps serving the copy it read on startup.
# @arg $@ string Application names, as `killall` expects them.
#
function restart_applications() {
    local app

    for app in "$@"; do
        killall "${app}" 2> /dev/null || echo "Skipping ${app}: it was not running."
    done
}

#
# @description Configure the menu bar and Control Center.
#
function defaults_ui() {
    # Show the battery charge as a number, not just the icon
    defaults -currentHost write com.apple.controlcenter BatteryShowPercentage -bool true
}

#
# @description Configure the built-in trackpad.
#   Tracking speed is left alone: it is a preference worth tuning per machine,
#   and overwriting it here would undo that on every fresh install. The
#   AppleBluetoothMultitouch domain is left out too, since there is no Magic
#   Trackpad to configure.
#
function defaults_trackpad() {
    # Tap to click, for this user and for the login screen
    defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
    defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

    # Drag a window with three fingers instead of holding the click down.
    # System Settings files this under Accessibility, not Trackpad.
    defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerDrag -bool true
}

#
# @description Apply every preference group.
#
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
