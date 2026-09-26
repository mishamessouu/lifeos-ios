#!/bin/sh
# Xcode Cloud runs this after it clones the repository.
#
# The project has one local Swift package and no remote ones. Xcode Cloud
# resolves packages only from a committed Package.resolved, and Xcode writes
# none for local packages (swiftlang/swift-package-manager issue 6914). The
# repository commits an empty one; these two defaults are the second guard.
set -e

defaults write com.apple.dt.Xcode IDEPackageOnlyUseVersionsFromResolvedFile -bool NO
defaults write com.apple.dt.Xcode IDEDisableAutomaticPackageResolution -bool NO

echo "ci_post_clone: package resolution allowed for the local LifeOSKit package."
