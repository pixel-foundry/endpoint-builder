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
			}
			"""
		} expansion: {
			"""
			public struct GetUserEndpoint {
				public static let path: [RoutingKit.PathComponent] = ["user", ":id"]
				public static let httpMethod = HTTPRequest.Method.get
				public static let responseType = User.self

				public var authorization: Authorization?

				public var path: String {
					"/" + ["user", pathParameters.id].joined(separator: "/")
				}

				public let pathParameters: PathParameters

				public struct PathParameters: Hashable, Sendable {
					public init(id: String) {
						self.id = id
					}
					public let id: String
				}
			}

			extension GetUserEndpoint: EndpointBuilder.Endpoint {
			}
			"""
		}
	}

	func testMultiplePathParameters() {
		assertMacro {
			"""
			@Endpoint
			public struct GetUserEndpoint {
				public static let path: [RoutingKit.PathComponent] = ["team", ":team-id", "user", ":user-id"]
				public static let httpMethod = HTTPRequest.Method.get
				public static let responseType = User.self
			}
			"""
		} expansion: {
			"""
			public struct GetUserEndpoint {
				public static let path: [RoutingKit.PathComponent] = ["team", ":team-id", "user", ":user-id"]
				public static let httpMethod = HTTPRequest.Method.get
				public static let responseType = User.self

				public var authorization: Authorization?

				public var path: String {
					"/" + ["team", pathParameters.teamId, "user", pathParameters.userId].joined(separator: "/")
				}

				public let pathParameters: PathParameters

				public struct PathParameters: Hashable, Sendable {
					public init(teamId: String, userId: String) {
						self.teamId = teamId
						self.userId = userId
					}
					public let teamId: String
					public let userId: String
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

	func testDiagnosticsForUnparsablePathDefinition() {
		// Referencing the `path` of another Endpoint is valid Swift but I don’t think there’s any way for
		// a Macro to expand the underlying type of the reference, so it’s easier to just emit diagnostics to forbid this.
		assertMacro {
			"""
			@Endpoint
			public struct One {
				public static let path: [RoutingKit.PathComponent] = ["one"]
				public static let httpMethod = HTTPRequest.Method.get
			}

			@Endpoint
			public struct Two {
				public static let path: [RoutingKit.PathComponent] = One.path
				public static let httpMethod = HTTPRequest.Method.get
			}
			"""
		} diagnostics: {
			"""
			@Endpoint
			public struct One {
				public static let path: [RoutingKit.PathComponent] = ["one"]
				public static let httpMethod = HTTPRequest.Method.get
			}

			@Endpoint
			public struct Two {
				public static let path: [RoutingKit.PathComponent] = One.path
			                                                    ┬─────────
			                                                    ╰─ 🛑 Could not parse `path`
				public static let httpMethod = HTTPRequest.Method.get
			}
			"""
		}
	}

}
