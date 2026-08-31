// swift-tools-version:6.0
import PackageDescription

// Command Line Tools only (no Xcode) ships Swift Testing as a framework under
// the active developer dir, but SwiftPM does not add it to the search path.
// Wire it up explicitly so `swift test` resolves `import Testing` and can load
// lib_TestingInterop.dylib at runtime. XCTest is NOT available in CLT.
let cltDeveloperDir = "/Library/Developer/CommandLineTools/Library/Developer"
let testingFrameworksPath = "\(cltDeveloperDir)/Frameworks"
let testingInteropLibPath = "\(cltDeveloperDir)/usr/lib"

let package = Package(
    name: "GlowCursor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GlowCursor",
            path: "Sources/GlowCursor",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "GlowCursorTests",
            dependencies: ["GlowCursor"],
            path: "Tests/GlowCursorTests",
            swiftSettings: [
                .swiftLanguageMode(.v5),
                .unsafeFlags(["-F", testingFrameworksPath]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", testingFrameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", testingFrameworksPath,
                    "-Xlinker", "-rpath", "-Xlinker", testingInteropLibPath,
                ]),
            ]
        ),
    ]
)
