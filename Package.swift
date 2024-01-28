// swift-tools-version:5.9
import CompilerPluginSupport
import PackageDescription

let package = Package(
	name: "endpoint-builder",
	platforms: [
		.iOS(.v13),
		.tvOS(.v13),
		.macOS(.v10_15),
		.watchOS(.v6),
		.visionOS(.v1)
	],
	products: [
		.library(name: "EndpointBuilder", targets: ["EndpointBuilder"])
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.0"),
		.package(url: "https://github.com/pointfreeco/swift-macro-testing", from: "0.2.0"),
		.package(url: "https://github.com/vapor/routing-kit", from: "4.9.0")
	],
	targets: [
		.target(
			name: "EndpointBuilder",
			dependencies: [
				.byName(name: "EndpointBuilderMacros"),
				.product(name: "HTTPTypes", package: "swift-http-types"),
				.product(name: "RoutingKit", package: "routing-kit")
			]
		),
		.testTarget(name: "EndpointBuilderTests", dependencies: ["EndpointBuilder"]),
		.macro(
			name: "EndpointBuilderMacros",
			dependencies: [
				.product(name: "RoutingKit", package: "routing-kit"),
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax")
			]
		),
		.testTarget(
			name: "EndpointBuilderMacrosTests",
			dependencies: [
				.byName(name: "EndpointBuilderMacros"),
				.product(name: "MacroTesting", package: "swift-macro-testing")
			]
		)
	]
)
