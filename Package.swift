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

import Darwin
import PackageDescription

// 清单只遍历源目录，不通过Foundation目录属性查询依赖CoreServices。
let packageRoot = #filePath.split(separator: "/", omittingEmptySubsequences: false).dropLast().joined(separator: "/")
let sourcesPath = packageRoot + "/Sources"
let metalFileExtension = ".metal"
let metalResourcePaths: [String] = {
    guard let root = strdup(sourcesPath) else { fatalError("Unable to allocate package source path") }
    defer { free(root) }
    var roots: [UnsafeMutablePointer<CChar>?] = [root, nil]
    guard let traversal = fts_open(&roots, FTS_PHYSICAL | FTS_NOCHDIR, nil) else {
        fatalError("Unable to enumerate package sources")
    }
    defer { fts_close(traversal) }
    var paths: [String] = []
    while true {
        errno = 0
        guard let entry = fts_read(traversal) else {
            guard errno == 0 else { fatalError("Unable to finish enumerating package sources") }
            break
        }
        let kind = Int32(entry.pointee.fts_info)
        if kind == FTS_DP { continue }
        guard kind != FTS_DNR, kind != FTS_ERR, kind != FTS_NS else {
            fatalError("Unable to read package source entry")
        }
        let path = String(cString: entry.pointee.fts_path)
        if path.hasSuffix(metalFileExtension) {
            paths.append(String(path.dropFirst(sourcesPath.count + 1)))
        }
    }
    return paths.sorted()
}()

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
