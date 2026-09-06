// swift-tools-version:6.2
//
//  Harbeth
//
//  Copyright (c) 2021 AT <https://github.com/yangKJ/Harbeth>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import Foundation
import PackageDescription

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let sourcesPath = packageRoot.appendingPathComponent("Sources").path
let metalFileExtension = ".metal"
let metalResourcePaths = FileManager.default.enumerator(atPath: sourcesPath)?.compactMap { item -> String? in
    guard let path = item as? String, path.hasSuffix(metalFileExtension) else { return nil }
    return path
}.sorted() ?? []
let metalResources = metalResourcePaths.map { Resource.process($0) }

let package = Package(
    name: "Harbeth",
    platforms: [.iOS(.v15), .macOS(.v12), .tvOS(.v15)],
    products: [.library(name: "Harbeth", targets: ["Harbeth"])],
    targets: [
        .target(name: "Harbeth", path: "Sources", resources: metalResources),
        .testTarget(name: "HarbethTests", dependencies: ["Harbeth"], path: "Tests/HarbethTests"),
        .testTarget(name: "HarbethPublicAPITests", dependencies: ["Harbeth"], path: "Tests/HarbethPublicAPITests"),
    ],
    swiftLanguageModes: [.v6]
)
