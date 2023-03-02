// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TcpSocket",
    products: [
        .library(name: "JWT", targets: ["JWT"]),
        .library(name: "TcpSocket", targets: ["TcpSocket"])
    ],
    targets: [
        .target(name: "JWT"),
        .target(name: "TcpSocket"),
        .testTarget(name: "Tests", dependencies: ["JWT", "TcpSocket"])
    ]
)
