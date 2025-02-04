//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import XCTest
import SwiftSyntax

@_spi(ExperimentalLanguageFeatures) import SwiftParser

/// The base class for all parser test cases.
public class ParserTestCase: XCTestCase {
  /// The default set of experimental features to test with.
  var experimentalFeatures: Parser.ExperimentalFeatures { [] }
}
