// swift-tools-version: 6.0
import PackageDescription

// LifeOSKit holds every rule of the app: models, JSON decoding, the client,
// the pair link parser, the reply queue, and the cursor merge. It builds and
// tests on Linux, so agents without a Mac can check it.
let package = Package(
    name: "LifeOSKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LifeOSKit", targets: ["LifeOSKit"]),
    ],
    targets: [
        .target(name: "LifeOSKit"),
        .testTarget(name: "LifeOSKitTests", dependencies: ["LifeOSKit"]),
    ]
)
