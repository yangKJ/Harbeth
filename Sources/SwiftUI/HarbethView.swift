//
//  HarbethView.swift
//  Harbeth
//
//  Created by Condy on 2023/12/5.
//

import SwiftUI

@available(*, deprecated, message: "Typo. Use `HarbethView` instead", renamed: "HarbethView")
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public typealias FilterableView<C: View> = HarbethView<C>

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct HarbethView<Content>: View where Content: View {
    
    public typealias Block = (Image) -> Content
    
    @ObservedObject private var source: Published_Source<C7Image>
    @ViewBuilder private var content: Block
    
    /// Create an instance from the provided value.
    /// - Parameters:
    ///   - image: Will deal image.
    ///   - filters: Need add filters.
    ///   - content: Callback a Image.
    ///   - async: Whether to use asynchronous processing, the UI will not be updated in real time.
    public init(image: C7Image, filters: [C7FilterProtocol], @ViewBuilder content: @escaping Block, async: Bool = false) {
        var input = HarbethViewInput(image: image)
        input.asynchronousProcessing = async
        input.filters = filters
        input.placeholder = image
        self.init(input: input, content: content)
    }
    
    /// Create an instance from the provided value.
    /// - Parameters:
    ///   - input: Input source.
    ///   - content: Callback a Image.
    public init(input: HarbethViewInput, @ViewBuilder content: @escaping Block) {
        self.content = content
        if let placeholder = input.placeholder {
            self.source = Published_Source(placeholder)
            self.setup(input: input)
        } else if let image = input.texture?.c7.toImage() {
            self.source = Published_Source(image)
            self.setup(input: input)
        } else {
            self.source = Published_Source(C7Image())
        }
    }
    
    func setup(input: HarbethViewInput) {
        guard !input.filters.isEmpty, let texture = input.texture else {
            return
        }
        let dest = HarbethIO(element: texture, filters: input.filters)
        if input.asynchronousProcessing {
            dest.transmitOutput(success: { source in
                if let image = source.c7.toImage() {
                    DispatchQueue.main.async {
                        self.source.source = image
                    }
                }
            })
        } else if let image = try? dest.output().c7.toImage() {
            self.source.source = image
        }
    }
    
    public var body: some View {
        self.content(disImage)
    }
    
    public var disImage: Image {
        get {
            Image.init(c7Image: source.source)
        }
    }
}
