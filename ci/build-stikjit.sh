#!/usr/bin/env bash
# Rebuild StikJIT 1.9.0 with full-width debugserver addresses. Its shipped
# nine-digit packet format truncates JIT mappings above 0xfffffffff on iPads.
set -euo pipefail

HENGE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STIKJIT_ROOT="${1:?StikJIT checkout path required}"
STIKJIT_REV=32287268fa5824f9edce4cb359f5833ce0cf7b00

git clone --depth 1 --branch 1.9.0 https://github.com/StikDebug/StikJIT.git "$STIKJIT_ROOT"
test "$(git -C "$STIKJIT_ROOT" rev-parse HEAD)" = "$STIKJIT_REV"
git -C "$STIKJIT_ROOT" apply "$HENGE_ROOT/ci/stikjit-high-address.patch"

cd "$STIKJIT_ROOT"
xcodegen generate
# The module is called StikJIT and so is its main enum. Compilers before Swift 6.4 write the interface's
# types as StikJIT.DDIPaths, which then names a member of the enum and does not import; aliasing the
# module names in the interface (6.4 writes StikJIT::DDIPaths instead) works with either.
xcodebuild archive -project StikJIT.xcodeproj -scheme StikJIT -configuration Release \
    -sdk iphoneos -destination 'generic/platform=iOS' -archivePath build/StikJIT \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO \
    OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -alias-module-names-in-module-interface' -quiet
xcodebuild -create-xcframework \
    -framework build/StikJIT.xcarchive/Products/Library/Frameworks/StikJIT.framework \
    -output StikJIT.xcframework
