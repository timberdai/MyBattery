// swift-tools-version:5.9
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import PackageDescription

let package = Package(
    name: "MyBattery",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MyBattery", targets: ["MyBattery"]),
        .library(name: "BatteryTimeCore", targets: ["BatteryTimeCore"]),
    ],
    dependencies: [
        .package(path: "Vendor/StatusItemKit"),
    ],
    targets: [
        .target(name: "BatteryTimeCore"),
        .executableTarget(
            name: "MyBattery",
            dependencies: ["BatteryTimeCore", .product(name: "StatusItemKit", package: "StatusItemKit")]
        ),
        .testTarget(name: "BatteryTimeCoreTests", dependencies: ["BatteryTimeCore"]),
        .testTarget(name: "MyBatteryTests", dependencies: ["MyBattery"]),
    ]
)
