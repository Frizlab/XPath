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

/* This wrapper has originally been created by Matt Gallagher on 4/08/08.
 * It has been heavily modified (conversion to swift, better libxml2 nodes to
 * object conversion, etc.) by François Lamboley. */

import Foundation

#if canImport(libxml2)
	import libxml2
#else
	import CLibXML2
#endif



public struct XPath {
	
	public enum Error : Swift.Error {
		
		case cannotCreateXMLDoc
		case cannotCreateXPathContext
		case cannotConvertQueryToCString
		case cannotEvaluateExpression
		case textNodeWithNoContent
		case cdataNodeWithNoContent
		case elementNodeWithNoName
		case invalidAttributeNodeInElement
		case attributeNodeWithNoName
		case attributeNodeWithNoContent
		case invalidContentNodeInElement
		
		case invalidUTF8
		
	}
	
	public indirect enum LibXML2Node {
		
		case element(name: String, attributes: [LibXML2AttributeNode], children: [LibXML2Node])
		case attribute(LibXML2AttributeNode)
		case text(String) /* libxml2 is written in a way which makes even text nodes susceptible to have children nodes. We assume they won't. */
		case cdata(Data) /* libxml2 is written in a way which makes even CData nodes susceptible to have children nodes. We assume they won't. */
		case other(type: xmlElementType, name: String?, value: Data?, children: [LibXML2Node]) /* We only support conversion for above types. We could add more if needed. Also, we assume other types don't have attributes (they currently don't at least). */
		
	}
	
	public struct LibXML2AttributeNode {
		var name: String
		var value: String
	}
	
	public static func performXMLXPathQuery(_ query: String, withDocument doc: Data) throws -> [LibXML2Node] {
		return try doc.withUnsafeBytes{ (bytes: UnsafeRawBufferPointer) -> [LibXML2Node] in
			let bytes = bytes.bindMemory(to: Int8.self).baseAddress!
			guard let doc = xmlReadMemory(bytes, Int32(doc.count), "", nil, Int32(XML_PARSE_RECOVER.rawValue)) else {throw Error.cannotCreateXMLDoc}
			defer {xmlFreeDoc(doc)}
			return try performXPathQuery(query, withDocument: doc)
		}
	}
	
	public static func performHTMLXPathQuery(_ query: String, withDocument doc: Data) throws -> [LibXML2Node] {
		return try doc.withUnsafeBytes{ (bytes: UnsafeRawBufferPointer) -> [LibXML2Node] in
			let bytes = bytes.bindMemory(to: Int8.self).baseAddress!
			guard let doc = htmlReadMemory(bytes, Int32(doc.count), "", nil, Int32(HTML_PARSE_NOWARNING.rawValue | HTML_PARSE_NOERROR.rawValue)) else {throw Error.cannotCreateXMLDoc}
			defer {xmlFreeDoc(doc)}
			return try performXPathQuery(query, withDocument: doc)
		}
	}
	
	/** Takes an array of LibXML2Nodes and outputs a string. Only .text and
	.cdata nodes are considered. */
	public static func textFrom(nodeList: [LibXML2Node]) throws -> String {
		var res = String()
		for n in nodeList {
			switch n {
			case .text(let str):
				res += str
				
			case .cdata(let data):
				guard let str = String(data: data, encoding: .utf8) else {throw Error.invalidUTF8}
				res += str
				
			default: (/*nop(ignored)*/)
			}
		}
		return res
	}
	
	public static func dictionaryFrom(attributeNodesList: [LibXML2AttributeNode]) -> [String: String] {
		var res = [String: String]()
		for a in attributeNodesList {res[a.name] = a.value}
		return res
	}
	
	/* ***************
	   MARK: - Private
	   *************** */
	
	private static func dataFromXmlCharPtr(_ ptr: UnsafePointer<xmlChar>) -> Data {
		/* ptr is a pointer to xmlChar (aka. UInt8).
		 * We convert it to an opaque pointer to retrieve un unsafe pointer raw
		 * pointer.
		 *
		 * Note: We can use strlen because 0x00 is an invalid byte in an XML doc. */
		let rawPtr = UnsafeRawPointer(OpaquePointer(ptr))
		return Data(bytes: rawPtr, count: Int(strlen(rawPtr.assumingMemoryBound(to: Int8.self))))
	}
	
	private static func stringFromXmlCharPtr(_ ptr: UnsafePointer<xmlChar>) throws -> String {
		/* ptr is a pointer to xmlChar (aka. UInt8).
		 * We convert it to an opaque pointer to retrieve un unsafe pointer to
		 * CChar (aka. Int8). */
		guard let ret = String(cString: UnsafePointer<CChar>(OpaquePointer(ptr)), encoding: .utf8) else {throw Error.invalidUTF8}
		return ret
	}
	
	private static func swiftNode(fromXMLNode node: xmlNodePtr) throws -> LibXML2Node {
		/* See https://www.w3.org/TR/REC-DOM-Level-1/level-one-core.html#ID-1841493061 for a list of node types and their values. */
		switch node.pointee.type {
		case XML_ELEMENT_NODE:
			/* Element name. Mandatory. */
			let namePtr = node.pointee.name
			guard let name = try namePtr.flatMap({ try stringFromXmlCharPtr($0) }) else {throw Error.elementNodeWithNoName}
			
			/* An element node should not have a content. (This is why it is not processed here.) */
			
			/* Attributes. */
			var attributes = [LibXML2AttributeNode]()
			var curAttribute = node.pointee.properties
			while let attribute = curAttribute {
				defer {curAttribute = attribute.pointee.next}
				
				switch try swiftNode(fromXMLNode: UnsafeMutablePointer<_xmlNode>(OpaquePointer(attribute))) {
				case .attribute(let swiftAttribute): attributes.append(swiftAttribute)
				default: throw Error.invalidAttributeNodeInElement
				}
			}
			
			/* Children nodes. */
			var children = [LibXML2Node]()
			var curChild = node.pointee.children
			while let child = curChild {
				children.append(try swiftNode(fromXMLNode: child))
				curChild = child.pointee.next
			}
			
			return .element(name: name, attributes: attributes, children: children)
			
		case XML_ATTRIBUTE_NODE:
			/* Element name. Mandatory. */
			let namePtr = node.pointee.name
			guard let name = try namePtr.flatMap({ try stringFromXmlCharPtr($0) }) else {throw Error.attributeNodeWithNoName}
			
			/* Element value. Mandatory. In the children attribute, as a text node, for whatever reason... */
			guard let valueNode = node.pointee.children else {throw Error.attributeNodeWithNoContent}
			switch try swiftNode(fromXMLNode: valueNode) {
			case .text(let text): return .attribute(LibXML2AttributeNode(name: name, value: text))
			default: throw Error.invalidContentNodeInElement
			}
			
		case XML_TEXT_NODE:
			/* node.pointee.name == "text" */
			guard let textContent = node.pointee.content else {throw Error.textNodeWithNoContent}
			return .text(try stringFromXmlCharPtr(textContent))
			
		case XML_CDATA_SECTION_NODE:
			/* node.pointee.name == "cdata-section" */
			guard let dataContent = node.pointee.content else {throw Error.cdataNodeWithNoContent}
			return .cdata(dataFromXmlCharPtr(dataContent))
			
		default:
			let namePtr = node.pointee.name
			let name = try namePtr.flatMap{ try stringFromXmlCharPtr($0) }
			
			let contentPtr = node.pointee.name
			let content = contentPtr.flatMap{ dataFromXmlCharPtr($0) }
			
			var children = [LibXML2Node]()
			var curChild = node.pointee.children
			while let child = curChild {
				defer {curChild = child.pointee.next}
				children.append(try swiftNode(fromXMLNode: child))
			}
			
			return .other(type: node.pointee.type, name: name, value: content, children: children)
		}
	}
	
	private static func performXPathQuery(_ query: String, withDocument document: xmlDocPtr) throws -> [LibXML2Node] {
		/* Create XPath evaluation context */
		guard let xpathCtx = xmlXPathNewContext(document) else {throw Error.cannotCreateXPathContext}
		defer {xmlXPathFreeContext(xpathCtx)}
		
		/* Evaluate XPath expression */
		guard let xmlCharQuery = query.cString(using: .utf8)?.map({ xmlChar($0) }) else {throw Error.cannotConvertQueryToCString}
		guard let xpathObj = xmlXPathEvalExpression(xmlCharQuery, xpathCtx) else {throw Error.cannotEvaluateExpression}
		defer {xmlXPathFreeObject(xpathObj)}
		
		guard let nodes = xpathObj.pointee.nodesetval else {
			return []
		}
		
		var resultNodes = [LibXML2Node]()
		for i in 0..<Int(nodes.pointee.nodeNr) {
			guard let nodePtr = nodes.pointee.nodeTab.advanced(by: i).pointee else {continue}
			resultNodes.append(try swiftNode(fromXMLNode: nodePtr))
		}
		
		return resultNodes
	}
	
}
