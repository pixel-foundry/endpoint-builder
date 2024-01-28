import Foundation

extension Never: Codable {

	public init(from decoder: Decoder) throws {
		throw DecodingError.dataCorrupted(
			DecodingError.Context(codingPath: [], debugDescription: "Never values cannot be decoded.")
		)
	}

	public func encode(to encoder: Encoder) throws {}

}
