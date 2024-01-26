import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct APIEndpointPlugin: CompilerPlugin {
	let providingMacros: [Macro.Type] = [
		EndpointMacro.self
	]
}
