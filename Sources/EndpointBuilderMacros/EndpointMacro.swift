import Foundation
import RoutingKit
import SwiftDiagnostics
import SwiftParser
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public enum EndpointMacro {}

extension EndpointMacro: ExtensionMacro {

	@inlinable
	public static func expansion<D: DeclGroupSyntax, T: TypeSyntaxProtocol, C: MacroExpansionContext>(
		of node: AttributeSyntax,
		attachedTo declaration: D,
		providingExtensionsOf type: T,
		conformingTo protocols: [TypeSyntax],
		in context: C
	) throws -> [ExtensionDeclSyntax] {
		if let inheritanceClause = declaration.inheritanceClause, inheritanceClause.inheritedTypes.contains(
			where: { ["Endpoint"].flatMap { [$0, "EndpointBuilder.\($0)"] }.contains($0.type.trimmedDescription) }
		) {
			return []
		}
		let ext: DeclSyntax =
			"""
			extension \(type.trimmed): EndpointBuilder.Endpoint {}
			"""
		return [ext.cast(ExtensionDeclSyntax.self)]
	}

}

extension EndpointMacro: MemberMacro {

	@inlinable
	public static func expansion<D: DeclGroupSyntax, C: MacroExpansionContext>(
		of node: AttributeSyntax,
		providingMembersOf declaration: D,
		in context: C
	) throws -> [DeclSyntax] {
		let authorizationDefinition = [
			VariableDeclSyntax(
				modifiers: declaration.modifiers,
				Keyword.var,
				name: PatternSyntax(stringLiteral: "authorization"),
				type: TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: "Authorization?"))
			).as(DeclSyntax.self)
		].compactMap { $0 }

		let (pathComponents, pathVariableSyntax) = try endpointPathParameters(declaration: declaration)
		let pathParameters = pathComponents.filter { pathComponent in
			guard case .parameter = pathComponent else {
				return false
			}
			return true
		}

		let pathDefinition = try pathDefinition(declaration: declaration, syntax: pathVariableSyntax, pathComponents)

		let structDefinition: [DeclSyntax] = try {
			guard !pathParameters.isEmpty else {
				return []
			}
			return try endpointPathParametersStructDefinition(declaration: declaration, pathParameters)
		}()

		return authorizationDefinition + pathDefinition + structDefinition
	}

	@usableFromInline
	static func endpointPathParameters<D: DeclGroupSyntax>(
		declaration: D
	) throws -> ([PathComponent], ArrayElementListSyntax?) {
		let variables = declaration
			.memberBlock
			.members
			.compactMap { $0.decl.as(VariableDeclSyntax.self) }

		// MARK: Extract `path` variable and parse into RoutingKit [PathComponent]

		guard let pathVariable = try variables.compactMap({ variable -> ArrayElementListSyntax? in
			let bindingNamedPath = variable.bindings.first(where: { binding in
				binding.pattern
					.as(IdentifierPatternSyntax.self)?
					.identifier.text == "path"
			})

			guard let element = bindingNamedPath?.typeAnnotation?.type
				.as(ArrayTypeSyntax.self)?.element else {
				return nil
			}

			guard ["PathComponent", "RoutingKit.PathComponent"].contains(element.trimmedDescription) else {
				return nil
			}

			guard let pathValue = bindingNamedPath?.initializer?.value.as(ArrayExprSyntax.self)?.elements else {
				throw Error
					.message("Could not parse `path`")
					.diagnostics(at: bindingNamedPath?.initializer.map { Syntax($0) } ?? Syntax(variable))
			}

			return pathValue
		}).first else {
			return ([], nil)
		}

		let pathComponents: [PathComponent] = pathVariable.compactMap { element in
			guard let stringValue = element.expression
				.as(StringLiteralExprSyntax.self)?
				.segments
				.reduce("", { partialResult, element in
					partialResult + (element.as(StringSegmentSyntax.self)?.content.text ?? "")
				}) else {
				return nil
			}
			return PathComponent(stringLiteral: stringValue)
		}

		return (pathComponents, pathVariable)
	}

	@usableFromInline
	static func pathDefinition<D: DeclGroupSyntax>(
		declaration: D,
		syntax: ArrayElementListSyntax?,
		_ pathComponents: [PathComponent]
	) throws -> [DeclSyntax] {
		[
			VariableDeclSyntax(
				modifiers: declaration.modifiers,
				bindingSpecifier: .keyword(.var),
				bindings: [
					PatternBindingSyntax(
						pattern: IdentifierPatternSyntax(identifier: .identifier("path")),
						typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: .identifier("String"))),
						accessorBlock: AccessorBlockSyntax(accessors: .getter(CodeBlockItemListSyntax([
							CodeBlockItemSyntax(item: .expr(ExprSyntax(InfixOperatorExprSyntax(
								leftOperand: StringLiteralExprSyntax(content: "/"),
								operator: BinaryOperatorExprSyntax(operator: .binaryOperator("+")),
								rightOperand: FunctionCallExprSyntax(
									calledExpression: MemberAccessExprSyntax(
										base: ArrayExprSyntax(elements: try ArrayElementListSyntax {
											for pathComponent in pathComponents {
												switch pathComponent {
												case let .constant(constant):
													ArrayElementSyntax(expression: StringLiteralExprSyntax(content: constant))
												case let .parameter(pathParameterName):
													ArrayElementSyntax(expression: MemberAccessExprSyntax(
														base: DeclReferenceExprSyntax(baseName: .identifier("pathParameters")),
														declName: DeclReferenceExprSyntax(baseName: .identifier(pathParameterName.camelCased))
													))
												case .anything:
													throw Error
														.message("`anything` path components are not supported")
														.diagnostics(at: syntax ?? Syntax(declaration))
												case .catchall:
													throw Error
														.message("`catchall` path components are not supported")
														.diagnostics(at: syntax ?? Syntax(declaration))
												}
											}
										}),
										declName: DeclReferenceExprSyntax(baseName: .identifier("joined"))
									),
									leftParen: .leftParenToken(),
									rightParen: .rightParenToken(),
									argumentsBuilder: {
										LabeledExprSyntax(label: "separator", expression: StringLiteralExprSyntax(content: "/"))
									}
								)
							))))
						])))
					)
				]
			).as(DeclSyntax.self)
		].compactMap({ $0 })
	}

	@usableFromInline
	static func endpointPathParametersStructDefinition<D: DeclGroupSyntax>(
		declaration: D,
		_ pathParameters: [PathComponent]
	) throws -> [DeclSyntax] {
		guard !pathParameters.isEmpty else {
			return []
		}
		let pathParameterBlockItems = pathParameters.map { pathParameter in
			MemberBlockItemSyntax(
				decl: VariableDeclSyntax(
					modifiers: declaration.modifiers,
					Keyword.let,
					name: PatternSyntax(stringLiteral: pathParameter.description.camelCased),
					type: TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: "String"))
				)
			)
		}
		let initializerBlockItem = MemberBlockItemSyntax(
			decl: InitializerDeclSyntax(
				modifiers: declaration.modifiers,
				signature: FunctionSignatureSyntax(
					parameterClause: FunctionParameterClauseSyntax(
						parameters: FunctionParameterListSyntax(pathParameters.map({ pathParameter in
							FunctionParameterSyntax(
								firstName: .identifier(pathParameter.description.camelCased),
								type: TypeSyntax(stringLiteral: "String"),
								trailingComma: pathParameter == pathParameters.last ? nil : TokenSyntax.commaToken()
							)
						}))
					)
				),
				body: CodeBlockSyntax(
					statements: CodeBlockItemListSyntax(pathParameters.map({ pathParameter in
						CodeBlockItemSyntax(item: .expr(ExprSyntax(InfixOperatorExprSyntax(
							leftOperand: MemberAccessExprSyntax(
								base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
								declName: DeclReferenceExprSyntax(baseName: .identifier(pathParameter.description.camelCased))
							),
							operator: AssignmentExprSyntax(),
							rightOperand: DeclReferenceExprSyntax(baseName: .identifier(pathParameter.description.camelCased))
						))))
					}))
				)
			)
		)
		return [
			VariableDeclSyntax(
				modifiers: declaration.modifiers,
				Keyword.let,
				name: PatternSyntax(stringLiteral: "pathParameters"),
				type: TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: "PathParameters"))
			).as(DeclSyntax.self),
			StructDeclSyntax(
				modifiers: declaration.modifiers,
				name: .identifier("PathParameters"),
				inheritanceClause: InheritanceClauseSyntax(
					inheritedTypes: InheritedTypeListSyntax {
						InheritedTypeSyntax(type: IdentifierTypeSyntax(name: TokenSyntax(stringLiteral: "Hashable")))
						InheritedTypeSyntax(type: IdentifierTypeSyntax(name: TokenSyntax(stringLiteral: "Sendable")))
					}
				),
				memberBlock: MemberBlockSyntax(
					members: MemberBlockItemListSyntax([initializerBlockItem] + pathParameterBlockItems)
				)
			).as(DeclSyntax.self)
		].compactMap({ $0 })
	}

}

extension EndpointMacro {

	enum Error: Swift.Error, DiagnosticMessage {

		case message(String)

		func diagnostics(at node: SyntaxProtocol) -> DiagnosticsError {
			DiagnosticsError(diagnostics: [Diagnostic(node: node, message: self)])
		}

		var message: String {
			switch self {
			case let .message(message):
				message
			}
		}

		var diagnosticID: MessageID {
			switch self {
			case let .message(message):
				MessageID(domain: "message", id: message)
			}
		}

		var severity: DiagnosticSeverity {
			.error
		}

	}

}

extension String {

	@usableFromInline var camelCased: Self {
		let splitCharacters = CharacterSet.whitespacesAndNewlines
			.union(CharacterSet.controlCharacters)
			.union(CharacterSet.punctuationCharacters)
			.union(CharacterSet.symbols)

		let split = split(omittingEmptySubsequences: true, whereSeparator: { character in
			return !character.unicodeScalars.allSatisfy { scalar in
				return !splitCharacters.contains(scalar)
			}
		})

		return split.map { component in
			if component == split.first {
				return component.lowercased()
			}
			return component.capitalized
		}.joined()
	}

}
