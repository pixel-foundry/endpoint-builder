import Foundation

/// HTTP authorization schemes
public enum Authorization: Sendable, Hashable {

	/// Basic authorization
	case basic(username: String, password: String)

	/// Bearer authorization
	case bearer(token: String)

	/// HTTP header string value
	public var headerValue: String {
		switch self {
		case let .basic(username, password):
			let encoded = Data("\(username):\(password)".utf8).base64EncodedString()
			return "Basic \(encoded)"
		case let .bearer(token):
			return "Bearer \(token)"
		}
	}

}
