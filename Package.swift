// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SuiviEleves",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SuiviElevesCore",
            path: "Sources/SuiviElevesCore"
        ),
        .executableTarget(
            name: "SuiviEleves",
            dependencies: ["SuiviElevesCore"],
            path: "Sources/SuiviEleves"
        ),
        // Vérification logique sans XCTest (tourne avec les Command Line Tools) :
        //   swift run SelfCheck
        .executableTarget(
            name: "SelfCheck",
            dependencies: ["SuiviElevesCore"],
            path: "Sources/SelfCheck"
        ),
    ]
)
