// swift-tools-version:5.0
import PackageDescription


let package = Package(
	name: "XPath",
	products: [
		.library(name: "XPath", targets: ["XPath"])
	],
	targets: [
		.systemLibrary(name: "CLibXML2", pkgConfig: "libxml-2.0", providers: [.apt(["libxml2-dev"])]),
		
		.target(name: "XPath", dependencies: ["CLibXML2"]),
		.testTarget(name: "XPathTests", dependencies: ["XPath"])
	]
)
