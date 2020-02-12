// swift-tools-version:5.2
import PackageDescription


var libxml2Targets = [PackageDescription.Target]()
#if !canImport(libxml2)
	libxml2Targets.append(.systemLibrary(name: "CLibXML2", pkgConfig: "libxml-2.0", providers: [.apt(["libxml2-dev"])]))
#endif

let package = Package(
	name: "XPath",
	products: [
		.library(name: "XPath", targets: ["XPath"])
	],
	targets: [
		.target(name: "XPath", dependencies: [] + libxml2Targets.map{ _ in "CLibXML2" }),
		.testTarget(name: "XPathTests", dependencies: ["XPath"])
	] + libxml2Targets
)
