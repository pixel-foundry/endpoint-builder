import EndpointBuilderMacros
import MacroTesting
import XCTest

final class EndpointBuilderMacrosTests: XCTestCase {

	override func invokeTest() {
		withMacroTesting(
			macros: [EndpointMacro.self]
		) {
			super.invokeTest()
		}
	}

	func testBasics() {
		assertMacro {
			"""
			@Endpoint
			public struct GetUserEndpoint {
				public static let path: [RoutingKit.PathComponent] = ["user", ":id"]
				public static let httpMethod = HTTPRequest.Method.get
				public static let responseType = User.self
				public let authorization: Authorization?
			}
			"""
		} expansion: {
			"""
			public struct GetUserEndpoint {
				public static let path: [RoutingKit.PathComponent] = ["user", ":id"]
				public static let httpMethod = HTTPRequest.Method.get
				public static let responseType = User.self
				public let authorization: Authorization?

				public var path: String {
					"/" + ["user", pathParameters.id].joined(separator: "/")
				}

				public let pathParameters: PathParameters

				public struct PathParameters: Hashable, Sendable {
					public let id: String
				}
			}

			extension GetUserEndpoint: EndpointBuilder.Endpoint {
			}
			"""
		}
	}

	func testDiagnosticsForUnsupportedPathComponent() {
		assertMacro {
			"""
			@Endpoint
			public struct GetUserEndpoint {
				public static let path: [RoutingKit.PathComponent] = ["user", "*"]
				public static let httpMethod = HTTPRequest.Method.get
				public static let responseType = User.self
			}
			"""
		} diagnostics: {
			"""
			@Endpoint
			public struct GetUserEndpoint {
				public static let path: [RoutingKit.PathComponent] = ["user", "*"]
			                                                       ┬──────────
			                                                       ╰─ 🛑 `anything` path components are not supported
				public static let httpMethod = HTTPRequest.Method.get
				public static let responseType = User.self
			}
			"""
		}
	}
}
