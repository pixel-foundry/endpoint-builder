@testable import EndpointBuilder
import Foundation
import HTTPTypes
import RoutingKit
import XCTest

@Endpoint
struct EndpointWithNoSpecifiedBodyOrResponse {
	static let path: [PathComponent] = ["example"]
	static let httpMethod: HTTPRequest.Method = .post
}

@Endpoint
struct GetUserProfile {
	static let path: [PathComponent] = ["users", ":user-id", "profile"]
	static let httpMethod: HTTPRequest.Method = .get
	static let responseType = String.self
}

class EndpointBuilderTests: XCTestCase {

	func testEndpointWithNoSpecifiedBodyOrResponse() {
		XCTAssertTrue(EndpointWithNoSpecifiedBodyOrResponse.BodyContent.self == Never.self)
		XCTAssertTrue(EndpointWithNoSpecifiedBodyOrResponse.Response.self == Never.self)

		let endpoint = EndpointWithNoSpecifiedBodyOrResponse()
		XCTAssertEqual(endpoint.path, "/example")
	}

	func testEndpointWithPathParameters() {
		let endpoint = GetUserProfile(
			pathParameters: GetUserProfile.PathParameters(userId: "my-user-id")
		)
		XCTAssertEqual(endpoint.path, "/users/my-user-id/profile")
		XCTAssertTrue(GetUserProfile.responseType == String.self)
	}

}
