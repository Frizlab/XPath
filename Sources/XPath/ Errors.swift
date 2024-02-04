import Foundation



public enum XPathError : Error {
	
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
typealias Err = XPathError
