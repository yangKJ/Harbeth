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
    
    @ObservedObject private var image: Published_Image
    @ViewBuilder private var content: (Image) -> Content
    
    /// Create an instance from the provided value.
    /// - Parameters:
    ///   - image: Will deal image.
    ///   - filters: Need add filters.
    ///   - content: Callback a Image.
    ///   - async: Whether to use asynchronous processing, the UI will not be updated in real time.
    public init(image: C7Image, filters: [C7FilterProtocol], @ViewBuilder content: @escaping (Image) -> Content, async: Bool = false) {
        self.image = Published_Image(image)
        self.content = content
        self.setup(filters: filters, async: async)
    }
    
    func setup(filters: [C7FilterProtocol], async: Bool) {
        let dest = HarbethIO(element: image.image, filters: filters)
        if async {
            dest.transmitOutput(success: { img in
                DispatchQueue.main.async {
                    self.image.image = img
                }
            })
        } else if let image_ = try? dest.output() {
            self.image.image = image_
        }
    }
    
    public var body: some View {
        self.content(Image.init(c7Image: image.image))
    }
}
