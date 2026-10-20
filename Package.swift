// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ChiikawaDesk",
    platforms: [.macOS(.v13)],
    targets: [.target(name: "PetGeometry"), .executableTarget(name: "ChiikawaDesk", dependencies: ["PetGeometry"], resources: [.copy("Resources")])],
    swiftLanguageModes: [.v5]
)
