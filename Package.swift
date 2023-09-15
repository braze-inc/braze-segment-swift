// swift-tools-version:5.7

import PackageDescription

let package = Package(
  name: "braze-segment-swift",
  platforms: [
    .iOS("13.0"),
    .tvOS("11.0"),
  ],
  products: [
    .library(
      name: "SegmentBraze",
      targets: ["SegmentBraze"]
    ),
    .library(
      name: "SegmentBrazeUI",
      targets: ["SegmentBrazeUI"]
    ),
  ],
  dependencies: [
    .package(
      url: "https://github.com/segmentio/analytics-swift",
      from: "1.1.2"
    ),
    .package(
      url:"https://github.com/braze-inc/braze-swift-sdk",
      from: "6.6.0"
    ),
  ],
  targets: [
    .target(
      name: "SegmentBraze",
      dependencies: [
        .product(name: "Segment", package: "analytics-swift"),
        .product(name: "BrazeKit", package: "braze-swift-sdk"),
      ]
    ),
    .target(
      name: "SegmentBrazeUI",
      dependencies: [
        .product(name: "Segment", package: "analytics-swift"),
        .product(name: "BrazeKit", package: "braze-swift-sdk"),
        .product(name: "BrazeUI", package: "braze-swift-sdk"),
      ]
    ),
  ]
)
