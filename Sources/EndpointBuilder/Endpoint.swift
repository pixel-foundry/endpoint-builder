import Foundation
import HTTPTypes
import RoutingKit

/// Describes an API endpoint
public protocol Endpoint: Sendable {

	associatedtype BodyContent: Codable
	associatedtype Response: Codable

	/// The path components for this endpoint
	static var path: [PathComponent] { get }

	/// The HTTP method for this endpoint
	static var httpMethod: HTTPRequest.Method { get }

	/// The response type of this endpoint
	static var responseType: Response.Type { get }

	/// Authorization headers to be sent along with the request
	var authorization: Authorization? { get }

	/// Request body content
	var body: BodyContent { get }

	/// The URL path for this endpoint
	var path: String { get }

}

public extension Endpoint {

	var authorization: Authorization? {
		nil
	}

	var body: Never {
		fatalError()
	}

	static var responseType: Never.Type {
		fatalError()
	}

}
