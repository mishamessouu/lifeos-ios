#!/bin/sh
# Type-checks the app model on Linux, where there is no UIKit.
# It builds App/LifeOS/AppModel.swift and Copy.swift against LifeOSKit,
# with stub UIKit and UserNotifications modules from scripts/typecheck/.
# This finds type errors only. It runs nothing, and it does not check the
# views or the extension. Scaffolding: delete it once CI builds the app.
# Run it from the repository root, with Swift 6 installed:
#   scripts/typecheck-app.sh
set -eu

repo=$(pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/Sources/UIKit" "$work/Sources/UserNotifications" "$work/Sources/AppCheck"
sed "s#REPO#$repo#" scripts/typecheck/Package.swift.in > "$work/Package.swift"
cp scripts/typecheck/UIKit/*.swift "$work/Sources/UIKit/"
cp scripts/typecheck/UserNotifications/*.swift "$work/Sources/UserNotifications/"
cp scripts/typecheck/AppCheck/*.swift App/LifeOS/AppModel.swift App/LifeOS/Copy.swift "$work/Sources/AppCheck/"
swift build --package-path "$work"
echo "typecheck-app: AppModel.swift and Copy.swift type-check."
