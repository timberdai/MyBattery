// swift-tools-version:5.9
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
// Copyright (c) 2026 Nicholas Smith

import PackageDescription

let package = Package(
    name: "StatusItemKit",
    platforms: [.macOS(.v13)],
    products: [.library(name: "StatusItemKit", targets: ["StatusItemKit"])],
    targets: [.target(name: "StatusItemKit")]
)
