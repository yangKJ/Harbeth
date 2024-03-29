//
//  CustomViews.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/4.
//

import SwiftUI
import Harbeth

struct CustomViews<F: C7FilterProtocol>: View {
    
    @State private var value: Float
    @State private var inputImage: C7Image
    
    private var filtering: (Float) -> F
    private let max: Float
    private let min: Float
    
    init(value: Float, filtering: @escaping (Float) -> F, min: Float, max: Float, inputImage: C7Image? = nil) {
        self.min = min
        self.max = max
        self.filtering = filtering
        _value = State(wrappedValue: value)
        _inputImage = State(wrappedValue: inputImage ?? R.image("IMG_0020")!)
    }
    
    var body: some View {
        VStack {
            HarbethView(image: inputImage, filters: [filtering(value)], content: { image in
                image.resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(idealHeight: R.width-30 / 2 * 3)
                    .padding()
            }, async: true)
            
            VStack(alignment: .leading) {
                Text("Parameter Value: \(value, specifier: "%.2f")")
                Slider(value: $value, in: min...max)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
            .padding()
        }
        .padding(.bottom)
        .toolbar(content: { Spacer() })
    }
}

struct CustomViews_Previews: PreviewProvider {
    static var previews: some View {
        CustomViews(value: C7Brightness.range.value, filtering: {
            C7Brightness.init(brightness: $0)
        }, min: C7Brightness.range.min, max: C7Brightness.range.max)
    }
}
