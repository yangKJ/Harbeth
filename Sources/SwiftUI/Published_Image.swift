//
//  Published_Image.swift
//  Harbeth
//
//  Created by Condy on 2023/12/5.
//

import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public final class Published_Image: ObservableObject {
    
    @Published public var image: C7Image
    
    public init(_ image: C7Image) {
        self.image = image
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public final class Published_Source<T>: ObservableObject {
    
    @Published public var source: T
    
    public init(_ source: T) {
        self.source = source
    }
}
