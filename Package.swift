// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "swiftui-split-view",
	platforms: [.iOS(.v16)],
	products: [
		.library(
			name: "SplitView",
			targets: ["SplitView"]
		),
	],
	targets: [
		.target(
			name: "SplitView"
		),
		.testTarget(
			name: "SplitViewTests",
			dependencies: ["SplitView"]
		),
	]
)
