/*
Copyright 2019 Frizlab

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License. */

import XCTest
@testable import XPath



class XPathTests: XCTestCase {
	
	override func setUp() {
	}
	
	override func tearDown() {
	}
	
	func testSimpleXPath() throws {
		let xmlData = Data(#"""
		<?xml version="1.0" encoding="UTF-8"?>
		<note>
			<to>Tove</to>
			<from>Jani</from>
			<heading>Reminder</heading>
			<body>Don't forget me this weekend!</body>
		</note>
		"""#.utf8)
		let results = try XPath.performXMLXPathQuery("/note/to", withDocument: xmlData)
		XCTAssertEqual(results.count, 1)
		
		guard let firstResult = results.first else {return}
		switch firstResult {
		case .element(name: let n, attributes: let attrs, children: let children):
			XCTAssertEqual(n, "to")
			XCTAssertEqual(attrs.count, 0)
			XCTAssertEqual(children.count, 1)
			
			guard let firstChild = children.first else {return}
			switch firstChild {
			case .text(let str): XCTAssertEqual(str, "Tove")
			default:             XCTAssert(false, "Invalid child type")
			}
			
		default:
			XCTAssert(false, "Invalid result type")
		}
	}
	
}
