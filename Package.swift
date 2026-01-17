// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodeBank",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "CodeBankCore",
            targets: ["CodeBankCore"]
        )
    ],
    dependencies: [
        // SQLite wrapper
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0"),
        // Apple's Swift Crypto for AES-GCM
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0"),
        // Syntax highlighting
        .package(url: "https://github.com/raspu/Highlightr.git", from: "2.1.0")
    ],
    targets: [
        .target(
            name: "CodeBankCore",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift"),
                .product(name: "Crypto", package: "swift-crypto"),
                "Highlightr"
            ],
            path: "CodeBank/Core"
        ),
        .testTarget(
            name: "CodeBankTests",
            dependencies: ["CodeBankCore"],
            path: "CodeBankTests"
        )
    ]
)
