#!/usr/bin/env bash
# Remove Sparkle's update feed from a VoiceInk source tree before it is built.
# Without SUFeedURL, Sparkle 2.9.2 starts without an alert, and "Check for
# Updates" fails instead of offering to replace this build with the official one.
#
# Usage: strip-sparkle.sh [VoiceInk source dir]   (default: current directory)
set -euo pipefail

src=${1:-.}
plist="$src/VoiceInk/Info.plist"

if [ ! -f "$plist" ]; then
  echo "strip-sparkle: $plist not found" >&2
  exit 1
fi

# A missing key means upstream changed how updates are configured; stop so a
# person reviews the new setup instead of assuming it is safe.
if ! plutil -extract SUFeedURL raw -o - "$plist" >/dev/null 2>&1; then
  echo "strip-sparkle: SUFeedURL not found in $plist; review upstream's update setup" >&2
  exit 1
fi

plutil -remove SUFeedURL "$plist"
plutil -replace SUEnableAutomaticChecks -bool NO "$plist"

if plutil -extract SUFeedURL raw -o - "$plist" >/dev/null 2>&1; then
  echo "strip-sparkle: SUFeedURL still present in $plist" >&2
  exit 1
fi

# Sparkle also takes a feed from other plists, build settings, or code
# (a feedURLString delegate method or a defaults write).
others=$(grep -rl --include='*.plist' --include='*.pbxproj' --include='*.xcconfig' \
  --include='*.swift' --include='*.m' -e SUFeedURL -e feedURLString -e setFeedURL \
  "$src" || true)
if [ -n "$others" ]; then
  echo "strip-sparkle: another update feed source remains:" >&2
  printf '%s\n' "$others" >&2
  exit 1
fi

echo "strip-sparkle: removed SUFeedURL from $plist; SUEnableAutomaticChecks = NO"
