// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppMCP",
    platforms: [.macOS(.v15)],
    products: [
        .library(
            name: "AppMCP",
            targets: ["AppMCP"]),
        .executable(
            name: "appmcpd",
            targets: ["appmcpd"])
    ],
    dependencies: [
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.7.1"),
        .package(url: "https://github.com/1amageek/AppPilot.git", exact: "1.1.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "AppMCP",
            dependencies: [
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "AppPilot", package: "AppPilot")
            ],
            swiftSettings: [.unsafeFlags(["-enable-bare-slash-regex"])]
        ),
        .executableTarget(
            name: "appmcpd",
            dependencies: [
                "AppMCP",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "AppMCPTests",
            dependencies: [
                "AppMCP"
            ]
        ),
    ]
)
