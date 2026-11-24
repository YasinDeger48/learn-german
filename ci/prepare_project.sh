#!/usr/bin/env bash
# Prepares the Xcode project on a macOS runner: newest Xcode, XcodeGen, app icon, Info.plist build number.
# Used by .github/workflows/ios.yml (compile check + IPA) and testflight.yml (signed upload).
#   ci/prepare_project.sh <build-number> [--require-ios26]
set -euo pipefail
build_number="${1:?build number}"
require_26="${2:-}"

# Newest Xcode on the runner (App Store Connect needs the iOS 26 SDK or later).
newest=$(ls -d /Applications/Xcode_*.app | grep -E 'Xcode_[0-9]+(\.[0-9]+)*\.app$' | sort -V | tail -n 1)
echo "Using $newest"
sudo xcode-select -s "$newest/Contents/Developer"
xcodebuild -version
sdk=$(xcrun --sdk iphoneos --show-sdk-version)
if [ "$require_26" = "--require-ios26" ] && [ "${sdk%%.*}" -lt 26 ]; then
  echo "::error::Newest Xcode on this runner has iOS SDK $sdk. App Store Connect needs iOS 26 or later."
  exit 1
fi

# Prebuilt XcodeGen is much faster than Homebrew (saves 1–3 macOS minutes per run).
if curl -sSL -o /tmp/xcodegen.zip https://github.com/yonaskolb/XcodeGen/releases/download/2.42.0/xcodegen.zip \
   && unzip -q -o /tmp/xcodegen.zip -d /tmp; then
  export PATH="/tmp/xcodegen/bin:$PATH"
else
  brew install xcodegen
fi

# App Store needs a 1024 px icon without transparency.
icons=Assets.xcassets/AppIcon.appiconset
mkdir -p "$icons"
echo '{"info":{"author":"xcode","version":1}}' > Assets.xcassets/Contents.json
sips -z 1024 1024 AppIcon.png --out /tmp/icon1024.png
sips -s format jpeg /tmp/icon1024.png --out /tmp/icon1024.jpg
sips -s format png /tmp/icon1024.jpg --out "$icons/icon-1024.png"
cat > "$icons/Contents.json" <<'JSON'
{"images":[{"filename":"icon-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}],"info":{"author":"xcode","version":1}}
JSON

plist=Info.plist
/usr/libexec/PlistBuddy -c "Delete :CFBundleIcons" "$plist" || true
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$plist"
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "$plist" || true
/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations array" "$plist" || true
/usr/libexec/PlistBuddy -c "Add :UISupportedInterfaceOrientations:0 string UIInterfaceOrientationPortrait" "$plist" || true
plutil -lint "$plist"
xcodegen generate
