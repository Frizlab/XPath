// swift-tools-version:5.0
import PackageDescription


let package = Package(
	name: "XPath",
	products: [
		.library(name: "XPath", targets: ["XPath"]),
	],
	targets: [
		.target(name: "XPath", dependencies: []),
		.testTarget(name: "XPathTests", dependencies: ["XPath"])
	]
)
