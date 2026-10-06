# voiceink-build

An unofficial build of [VoiceInk](https://github.com/Beingpax/VoiceInk), a macOS
dictation app licensed under GPL-3.0. It is built from upstream source for the
owner's Macs and is not affiliated with or supported by the VoiceInk project.
The official app, with automatic updates, is available from
[upstream](https://github.com/Beingpax/VoiceInk).

## How it differs from the official app

- It is built with upstream's `make local` target, which upstream provides for
  building the app yourself.
- Update checks are removed. `patches/strip-sparkle.sh` deletes the Sparkle
  update feed (`SUFeedURL`) from the source before the build, so the app never
  offers to replace itself with the official build.
- Custom transcription models can show a live preview. `patches/live-preview.patch`
  lets a custom model use the mode's "Real-time" toggle: while you speak, the
  recorder shows words from xAI's streaming API, using the xAI API key entered in
  VoiceInk's settings. When you stop, the stream is dropped and the recording is
  sent to the custom model's endpoint as before, so the pasted text never comes
  from the stream. If the stream cannot start (for example, with no xAI key) or
  fails, the paste is unaffected. The preview uses VoiceInk's dictionary words,
  so its spellings can differ from the paste. The toggle is on for a new mode and
  turns on when you pick a model in a mode's settings; a mode saved with it off
  keeps it off.
- Text from a custom model is pasted without VoiceInk's output filter, which
  deletes filler words such as "mm" and "hm" and anything in brackets or
  parentheses, so "5 mm" and "(the old one)" survive.
- It is signed with a self-signed certificate, "VoiceInk Local", instead of an
  Apple Developer ID, and it is not notarized. The workflow signs with that one
  certificate each time, and macOS ties permissions such as Microphone and Accessibility
  to it, so the permissions carry over to new builds. The certificate's SHA-1
  is in `signing.env`.

## How it is built

`.github/workflows/build.yml` runs on a GitHub-hosted macOS runner when a build
input changes on `main`, or when started by hand. It:

1. checks out VoiceInk and whisper.cpp at the commits pinned in `upstream.env`,
   and uses the Xcode version pinned there;
2. removes the update feed and applies `patches/live-preview.patch`, failing if
   the patch no longer applies;
3. runs `make local`, signing with the certificate held in a repository secret;
4. checks the signature, the designated requirement, the entitlements, the
   version, and that the update feed is gone (`scripts/verify-app.sh`);
5. publishes `VoiceInk-<version>-r<N>.tar.xz` as a release and records its URL
   and SHA-256 in `dist/release.json`.

`.github/workflows/upstream-check.yml` runs weekly and opens an issue when
upstream has a newer stable release. Moving to it is a manual edit of
`upstream.env`.

To build the same way on a Mac with Xcode and your own code-signing identity:

```sh
git clone https://github.com/Beingpax/VoiceInk.git && cd VoiceInk
git checkout <VOICEINK_REV from upstream.env>
/path/to/voiceink-build/patches/strip-sparkle.sh .
git apply /path/to/voiceink-build/patches/live-preview.patch
XCODE_XCCONFIG_FILE=/path/to/voiceink-build/sign.xcconfig \
  make local LOCAL_CODESIGN_IDENTITY="VoiceInk Local"
```

Change `CODE_SIGN_IDENTITY` in `sign.xcconfig` if your identity has another
name. `make local` clones the latest whisper.cpp into `~/VoiceInk-Dependencies`
unless a build is already there; the workflow builds the pinned release there
first. The app is written to `~/Downloads/VoiceInk.app`.

## License

The scripts and workflows here are licensed under GPL-3.0, the same license as
VoiceInk; see `LICENSE`. VoiceInk itself is the work of its authors.
