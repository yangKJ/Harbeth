//
//  AsyncDest.swift
//  Harbeth
//
//  Created by Condy on 2023/8/25.
//

import Foundation

@available(*, deprecated, message: "This is not recommended, please use the `HarbethView`.")
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public class AsyncDest<Dest>: ObservableObject {
    
    /// Output dest
    @Published public private(set) var bookmarks: Dest?
    
    @Published public var error: HarbethError?
    
    public init() { }
    
    public func output(with source: Dest, filter: C7FilterProtocol) async {
        await output(with: source, filters: [filter])
    }
    
    public func output(with source: Dest, filters: [C7FilterProtocol]) async {
        let dest = HarbethIO(element: source, filters: filters)
        dest.transmitOutput(success: { [weak self] img in
            guard let `self` = self else { return }
            DispatchQueue.main.async {
                self.bookmarks = img
            }
        }, failed: { [weak self] in
            self?.error = $0
        })
    }
    
    public static func transmitOutput(with source: Dest, filter: C7FilterProtocol) async throws -> Dest {
        try await transmitOutput(with: source, filters: [filter])
    }
    
    public static func transmitOutput(with source: Dest, filters: [C7FilterProtocol]) async throws -> Dest {
        let dest = HarbethIO(element: source, filters: filters)
        return try await withCheckedThrowingContinuation({ (continuation: CheckedContinuation<Dest, Error>) in
            dest.transmitOutput { image in
                continuation.resume(returning: image)
            } failed: { error in
                continuation.resume(throwing: error)
            }
        })
    }
}
