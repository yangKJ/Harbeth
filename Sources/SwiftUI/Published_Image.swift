//
//  Published_Image.swift
//  Harbeth
//
//  Created by Condy on 2023/12/5.
//

import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public final class Published_Image: ObservableObject {
    
    @Published public var image: C7Image
    
    public init(_ image: C7Image) {
        self.image = image
    }
}
