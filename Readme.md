# XPath for Swift
A wrapper around libxml2’s XPath facilities.

SPM and Carthage compatible.

For SPM on macOS, because the headers for the system libraries are no longer installed in the system,
one (usually) has to launch the Swift commands with the following options:
```
-Xcc -I"`xcode-select -p`/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/libxml2"
```
I did not find a way to circumvent the problem (on macOS 10.14.4 w/ Xcode 10.2, without installing
_macOS_SDK_headers_for_macOS_10.14_ which is deprecated). If you have a suggestion, feel free
to help out!
