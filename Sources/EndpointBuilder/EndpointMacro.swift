import HTTPTypes
import RoutingKit

/// Conforms a type to the `Endpoint` protocol.
///
/// Generates a `path` string for the given path components,
/// along with a helper type for initializing any path parameters.
@attached(extension, conformances: Endpoint)
@attached(member, names: named(PathParameters), named(pathParameters), named(path))
public macro Endpoint() = #externalMacro(module: "EndpointBuilderMacros", type: "EndpointMacro")
