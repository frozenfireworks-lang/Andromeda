// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "AndromedaCoordinates",
    platforms: [.macOS(.v12)],
    products: [.library(name: "AndromedaCoordinates", targets: ["AndromedaCoordinates"])],
    targets: [
        .target(name: "AndromedaCoordinates", path: "Geranium/LocSim",
                exclude: ["BookMark", "AppProfilesView.swift", "CustomMapView.swift", "FavoritesView.swift", "FloatingQuickMenu.swift", "JoystickView.swift", "LocSimManager.swift", "LocSimPrivateHeaders.h", "LocSimView.swift", "RouteSimView.swift", "RouteSimulator.swift"],
                sources: ["CoordTransform.swift", "CoordinatePolicy.swift", "RouteGeometry.swift", "GPXParser.swift"]),
        .testTarget(name: "CoordinateTests", dependencies: ["AndromedaCoordinates"], path: "Tests/CoordinateTests")
    ])
