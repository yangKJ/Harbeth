//
//  FilterImage.swift
//  Harbeth
//
//  Created by Condy on 2023/8/2.
//

import Foundation
import SwiftUI

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public struct FilterImage : View {
    
    private let inputImage: C7Image
    private let filters: [C7FilterProtocol]
    private let builder: (C7Image) -> Image
    
    public init(with image: C7Image, filters: [C7FilterProtocol], @ViewBuilder builder: @escaping (C7Image) -> Image = Image.init(c7Image:)) {
        self.inputImage = image
        self.filters = filters
        self.builder = builder
    }
    
    public var body: some View {
        ZStack {
            switch Result(catching: {
                try setupImage()
            }) {
            case .success(let image):
                builder(image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure(let error):
                Text(error.localizedDescription)
            }
        }
    }
    
    private func setupImage() throws -> C7Image {
        let dest = BoxxIO(element: inputImage, filters: filters)
        return try dest.output()
    }
}
