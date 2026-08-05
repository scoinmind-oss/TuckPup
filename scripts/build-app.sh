#!/bin/zsh

set -euo pipefail

script_dir=${0:A:h}
project_dir=${script_dir:h}
build_dir="$project_dir/.build"
dist_dir="$project_dir/dist"
app_dir="$dist_dir/TuckPup.app"
contents_dir="$app_dir/Contents"
resources_dir="$contents_dir/Resources"
icon_source="$project_dir/Sources/TuckPup/Resources/BichonMenuIcon.png"
iconset_dir="$build_dir/AppIcon.iconset"

cd "$project_dir"
mkdir -p "$build_dir/ModuleCache"
CLANG_MODULE_CACHE_PATH="$build_dir/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$build_dir/ModuleCache" \
swift build -c release

rm -rf "$app_dir"
mkdir -p "$contents_dir/MacOS" "$resources_dir"
cp "$build_dir/release/TuckPup" "$contents_dir/MacOS/TuckPup"
cp "$project_dir/Info.plist" "$contents_dir/Info.plist"
cp "$icon_source" "$resources_dir/BichonMenuIcon.png"

mkdir -p "$iconset_dir"
sips -z 16 16 "$icon_source" --out "$iconset_dir/icon_16x16.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset_dir/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$icon_source" --out "$iconset_dir/icon_32x32.png" >/dev/null
sips -z 64 64 "$icon_source" --out "$iconset_dir/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$icon_source" --out "$iconset_dir/icon_128x128.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset_dir/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$icon_source" --out "$iconset_dir/icon_256x256.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset_dir/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$icon_source" --out "$iconset_dir/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$icon_source" --out "$iconset_dir/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$iconset_dir" -o "$resources_dir/AppIcon.icns"

xattr -cr "$app_dir"

# Privacy permissions on macOS are tied to the app's designated requirement.
# An ad-hoc signature changes identity whenever the executable changes, which
# makes Accessibility and Screen Recording prompt again after every build.
signing_identity=${TUCKPUP_CODESIGN_IDENTITY:-}
if [[ -z "$signing_identity" ]]; then
    identity_list=$(security find-identity -v -p codesigning 2>/dev/null || true)
    signing_identity=$(printf '%s\n' "$identity_list" | awk -F '"' '
        /Developer ID Application:|Apple Development:|Mac Developer:/ {
            print $2
            exit
        }
    ')
fi

if [[ -z "$signing_identity" ]]; then
    print -u2 "TuckPup needs a persistent code-signing identity."
    print -u2 "In Xcode: Settings > Accounts > Manage Certificates > + > Apple Development."
    print -u2 "Create it once, then run this build again. Ad-hoc signing is intentionally disabled."
    exit 1
fi

codesign \
    --force \
    --deep \
    --sign "$signing_identity" \
    --entitlements "$project_dir/TuckPup.entitlements" \
    "$app_dir"
xattr -cr "$app_dir"
codesign --verify --deep --strict "$app_dir"

echo "Signed with: $signing_identity"
echo "$app_dir"
