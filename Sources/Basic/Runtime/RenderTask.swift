//
//  RenderTask.swift
//  Harbeth
//
//  Created by Condy on 2026/6/21.
//

import Foundation
import Metal

/// A GPU render task handle for callers that need to observe command-buffer status.
public final class RenderTask<Output> {
    public let identifier: String
    public let diagnostics: RenderPlanDiagnostics?

    private let commandBuffer: MTLCommandBuffer?
    private let outputValue: Output
    private let lock = NSLock()
    private var completionHandlers: [(RenderTask<Output>) -> Void] = []
    private var cleanup: (() -> Void)?
    private var completed = false

    init(identifier: String,
         commandBuffer: MTLCommandBuffer,
         output: Output,
         diagnostics: RenderPlanDiagnostics?,
         cleanup: (() -> Void)? = nil) {
        self.identifier = identifier
        self.commandBuffer = commandBuffer
        self.outputValue = output
        self.diagnostics = diagnostics
        self.cleanup = cleanup

        commandBuffer.addCompletedHandler { [weak self] _ in
            self?.finish()
        }
    }

    private init(identifier: String, output: Output, diagnostics: RenderPlanDiagnostics?) {
        self.identifier = identifier
        self.commandBuffer = nil
        self.outputValue = output
        self.diagnostics = diagnostics
        self.completed = true
    }

    public static func completed(identifier: String = UUID().uuidString,
                                 output: Output,
                                 diagnostics: RenderPlanDiagnostics? = nil) -> RenderTask<Output> {
        RenderTask(identifier: identifier, output: output, diagnostics: diagnostics)
    }

    public var commandBufferStatus: MTLCommandBufferStatus {
        commandBuffer?.status ?? .completed
    }

    public var error: Error? {
        commandBuffer?.error
    }

    public var isCompleted: Bool {
        if commandBuffer == nil { return true }
        return commandBufferStatus == .completed || commandBufferStatus == .error
    }

    public func diagnosticsJSONData(prettyPrinted: Bool = false,
                                    sortedKeys: Bool = true) throws -> Data? {
        try diagnostics?.jsonData(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func diagnosticsJSONString(prettyPrinted: Bool = false,
                                      sortedKeys: Bool = true) throws -> String? {
        try diagnostics?.jsonString(prettyPrinted: prettyPrinted, sortedKeys: sortedKeys)
    }

    public func waitUntilCompleted() {
        commandBuffer?.waitUntilCompleted()
        if commandBuffer == nil {
            finish()
        }
    }

    public func output() throws -> Output {
        waitUntilCompleted()
        if let error {
            throw error
        }
        guard commandBufferStatus == .completed else {
            throw HarbethError.commandBufferAsyncCommit(commandBufferStatus)
        }
        return outputValue
    }

    public func observeCompletion(_ handler: @escaping (RenderTask<Output>) -> Void) {
        lock.lock()
        let shouldCallNow = completed || isCompleted
        if shouldCallNow == false {
            completionHandlers.append(handler)
        }
        lock.unlock()

        if shouldCallNow {
            handler(self)
        }
    }

    private func finish() {
        lock.lock()
        if completed {
            lock.unlock()
            return
        }
        completed = true
        let cleanup = self.cleanup
        self.cleanup = nil
        let handlers = completionHandlers
        completionHandlers.removeAll()
        lock.unlock()

        cleanup?()
        handlers.forEach { $0(self) }
    }
}
