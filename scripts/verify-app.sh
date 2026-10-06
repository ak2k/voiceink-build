#!/usr/bin/env bash
# Check a signed VoiceInk.app before it is packaged or released. Runs every
# check, prints each result, and exits 1 if any check failed.
#
# Usage: verify-app.sh <VoiceInk.app> <expected version, e.g. 2.21> <certificate SHA-1, hex>
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: $0 <VoiceInk.app> <version> <cert-sha1>" >&2
  exit 2
fi
app=$1
want_version=$2
want_sha1=$(printf '%s' "$3" | tr 'A-F' 'a-f')
bundle_id=com.prakashjoshipax.VoiceInk
identity="VoiceInk Local"
info="$app/Contents/Info.plist"

if ! [[ $want_sha1 =~ ^[0-9a-f]{40}$ ]]; then
  echo "verify-app: certificate SHA-1 must be 40 hex digits" >&2
  exit 2
fi
if [ ! -f "$info" ]; then
  echo "verify-app: $info not found" >&2
  exit 2
fi

failures=0
pass() { echo "ok:   $1"; }
fail() { echo "FAIL: $1"; failures=$((failures + 1)); }

if codesign --verify --deep --strict --verbose=2 "$app"; then
  pass "signature valid (--deep --strict)"
else
  fail "signature invalid"
fi

# TCC keys grants on the designated requirement. A certificate hash keeps them
# across builds; a cdhash (ad-hoc) requirement loses them on every build.
# A certificate trusted at signing time yields "root", an untrusted one "leaf";
# codesign prints the identifier with or without quotes.
dr_out=$(codesign -d -r- "$app" 2>&1 || true)
dr=$(sed -n 's/^designated => //p' <<<"$dr_out")
echo "      designated requirement: $dr"
want_dr="^identifier \"?${bundle_id//./\\.}\"? and certificate (root|leaf) = H\"$want_sha1\"\$"
if [[ $dr =~ $want_dr ]]; then
  pass "designated requirement pins certificate $want_sha1"
else
  fail "designated requirement does not match: $want_dr"
fi

details=$(codesign -dvv "$app" 2>&1 || true)
if grep -qx "Authority=$identity" <<<"$details" && ! grep -q '^Signature=adhoc' <<<"$details"; then
  pass "signed by \"$identity\", not ad-hoc"
else
  fail "not signed by \"$identity\" (or ad-hoc)"
fi

# Upstream's local entitlements disable library validation so a self-signed
# app can load the frameworks it embeds under the hardened runtime.
ents=$(mktemp)
trap 'rm -f "$ents"' EXIT
if codesign -d --entitlements - --xml "$app" >"$ents" 2>/dev/null &&
  [ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.cs.disable-library-validation' "$ents" 2>/dev/null)" = true ]; then
  pass "entitlement com.apple.security.cs.disable-library-validation = true"
else
  fail "entitlement com.apple.security.cs.disable-library-validation missing or false"
fi

if plutil -extract SUFeedURL raw -o - "$info" >/dev/null 2>&1; then
  fail "SUFeedURL present in Info.plist"
else
  pass "no SUFeedURL in Info.plist"
fi

got_id=$(plutil -extract CFBundleIdentifier raw -o - "$info" 2>/dev/null || true)
if [ "$got_id" = "$bundle_id" ]; then
  pass "CFBundleIdentifier = $bundle_id"
else
  fail "CFBundleIdentifier = '$got_id', expected $bundle_id"
fi

got_version=$(plutil -extract CFBundleShortVersionString raw -o - "$info" 2>/dev/null || true)
if [ "$got_version" = "$want_version" ]; then
  pass "CFBundleShortVersionString = $want_version"
else
  fail "CFBundleShortVersionString = '$got_version', expected $want_version"
fi

if [ "$failures" -ne 0 ]; then
  echo "verify-app: $failures check(s) failed for $app" >&2
  exit 1
fi
echo "verify-app: all checks passed for $app"
