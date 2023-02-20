// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TcpSocket",
    products: [
        .library(name: "TcpSocket", targets: ["TcpSocket"]),
        .executable(name: "TcpServer", targets: ["TcpServer"])
    ],
    targets: [
        .target(name: "TcpSocket"),
        .target(name: "TcpServer", dependencies: ["TcpSocket"]),
        .testTarget(name: "TcpSocketTests", dependencies: ["TcpSocket"])
    ]
)
