//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

//==========================================================================//
// IMPORTANT: The macros defined in this file are intended to test the      //
// behavior of MacroSystem. Many of them do not serve as good examples of   //
// how macros should be written. In particular, they often lack error       //
// handling because it is not needed in the few test cases in which these   //
// macros are invoked.                                                      //
//==========================================================================//

import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosTestSupport
import XCTest

fileprivate struct DeclsFromStringsMacro: DeclarationMacro {
  static func expansion(
    of node: some FreestandingMacroExpansionSyntax,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    var strings: [String] = []
    for arg in node.argumentList {
      guard let value = arg.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue else {
        continue
      }
      strings.append(value)
    }

    return strings.map { "\(raw: $0)" }
  }
}

final class DeclarationMacroTests: XCTestCase {
  private let indentationWidth: Trivia = .spaces(2)

  func testErrorExpansion() {
    struct ErrorMacro: DeclarationMacro {
      static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
      ) throws -> [DeclSyntax] {
        guard let firstElement = node.argumentList.first,
          let stringLiteral = firstElement.expression
            .as(StringLiteralExprSyntax.self),
          stringLiteral.segments.count == 1,
          case let .stringSegment(messageString) = stringLiteral.segments.first
        else {
          throw MacroExpansionErrorMessage("#error macro requires a string literal")
        }

        context.diagnose(
          Diagnostic(
            node: Syntax(node),
            message: MacroExpansionErrorMessage(messageString.content.description)
          )
        )

        return []
      }
    }

    assertMacroExpansion(
      """
      #myError("please don't do that")
      struct X {
        func f() { }
        #myError(bad)
        func g() {
          #myError("worse")
        }
      }
      """,
      expandedSource: """
        struct X {
          func f() { }
          #myError(bad)
          func g() {
          }
        }
        """,
      diagnostics: [
        DiagnosticSpec(message: "please don't do that", line: 1, column: 1, highlight: #"#myError("please don't do that")"#),
        DiagnosticSpec(message: "#error macro requires a string literal", line: 4, column: 3, highlight: #"#myError(bad)"#),
        DiagnosticSpec(message: "worse", line: 6, column: 5, highlight: #"#myError("worse")"#),
      ],
      macros: ["myError": ErrorMacro.self],
      indentationWidth: indentationWidth
    )
  }

  func testBitwidthNumberedStructsExpansion() {
    struct DefineBitwidthNumberedStructsMacro: DeclarationMacro {
      static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
      ) throws -> [DeclSyntax] {
        guard let stringLiteral = node.argumentList.first?.expression.as(StringLiteralExprSyntax.self),
          stringLiteral.segments.count == 1,
          case let .stringSegment(prefix) = stringLiteral.segments.first
        else {
          throw MacroExpansionErrorMessage(
            "#bitwidthNumberedStructs macro requires a string literal"
          )
        }

        return [8, 16, 32, 64].map { bitwidth in
          """

          struct \(raw: prefix)\(raw: String(bitwidth)) { }
          """
        }
      }
    }

    assertMacroExpansion(
      """
      #bitwidthNumberedStructs("MyInt")
      """,
      expandedSource: """
        struct MyInt8 {
        }
        struct MyInt16 {
        }
        struct MyInt32 {
        }
        struct MyInt64 {
        }
        """,
      macros: ["bitwidthNumberedStructs": DefineBitwidthNumberedStructsMacro.self],
      indentationWidth: indentationWidth
    )
  }

  func testDeclsFromStringLiterals() {
    struct DeclsFromStringsMacroNoAttrs: DeclarationMacro {
      static var propagateFreestandingMacroAttributes: Bool { false }
      static var propagateFreestandingMacroModifiers: Bool { false }

      static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
      ) throws -> [DeclSyntax] {
        var strings: [String] = []
        for arg in node.argumentList {
          guard let value = arg.expression.as(StringLiteralExprSyntax.self)?.representedLiteralValue else {
            continue
          }
          strings.append(value)
        }

        return strings.map { "\(raw: $0)" }
      }
    }

    assertMacroExpansion(
      #"""
      #decls(
        """
        static func foo() {
        print("value") }
        """,
        "struct Inner {\n\n}"
      )
      """#,
      expandedSource: #"""
        static func foo() {
          print("value")
        }
        struct Inner {

        }
        """#,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      #"""
      struct S {
        public #decls(
          """
          static func foo() {
          print("value") }
          """,
          "struct Inner {\n\n}"
        )
      }
      """#,
      expandedSource: #"""
        struct S {
          public static func foo() {
            print("value")
          }
          public struct Inner {

          }
        }
        """#,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      #"""
      struct S {
        @attr static #decls("var value1 = 1", "typealias A = B")
      }
      """#,
      expandedSource: #"""
        struct S {
          @attr static var value1 = 1
          @attr static typealias A = B
        }
        """#,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      #"""
      @attribute
      @otherAttribute(x: 1) #decls("@moreAttibute var global = 42")
      """#,
      expandedSource: #"""
        @attribute
        @otherAttribute(x: 1) @moreAttibute var global = 42
        """#,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )

    assertMacroExpansion(
      #"""
      @attribute
      @otherAttribute(x: 1)
      public #decls("@moreAttibute var global = 42",
                    "private func foo() {}")
      """#,
      expandedSource: #"""
        @moreAttibute var global = 42
        private func foo() {
        }
        """#,
      macros: ["decls": DeclsFromStringsMacroNoAttrs.self],
      indentationWidth: indentationWidth
    )
  }

  func testIndentationOfMultipleModifiers() {
    assertMacroExpansion(
      """
      struct Foo {
        public
        static #decls("func foo() {}")
      }
      """,
      expandedSource: """
        struct Foo {
          public
          static func foo() {
          }
        }
        """,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )
  }

  func testCommentsOnFreestandingDeclsExpansions() {
    assertMacroExpansion(
      """
      // some comment
      #decls(
        "func foo() {}",
        "func bar() {}"
      ) /* trailing comment */
      """,
      expandedSource: """
        // some comment
        func foo() {
        }
        func bar() {
        } /* trailing comment */
        """,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )
  }

  func testCommentsOnFreestandingDeclsExpansionsInMemberDeclList() {
    assertMacroExpansion(
      """
      struct Foo {
        // some comment
        #decls(
          "func foo() {}",
          "func bar() {}"
        ) /* trailing comment */
      }
      """,
      expandedSource: """
        struct Foo {
          // some comment
          func foo() {
          }
          func bar() {
          } /* trailing comment */
        }
        """,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )
  }

  func testFreestandingDeclThatIncludesDocComment() {
    assertMacroExpansion(
      #"""
      struct Foo {
        #decls(
          """
          /// Some doc comment
          func foo() {}
          """
        )
      }
      """#,
      expandedSource: """
        struct Foo {
          /// Some doc comment
          func foo() {
          }
        }
        """,
      macros: ["decls": DeclsFromStringsMacro.self],
      indentationWidth: indentationWidth
    )
  }
}
