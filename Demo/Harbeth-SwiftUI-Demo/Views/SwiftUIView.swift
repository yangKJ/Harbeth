//
//  SwiftUIView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/2.
//

import SwiftUI
import Harbeth

struct SwiftUIView: View {
    
    @State private var intensity: Float = 0.3
    @State private var inputImage = R.image("IMG_0020")!
    
    var body: some View {
        VStack {
            let filters: [C7FilterProtocol] = [
                CIHighlight(highlight: intensity),
                C7WaterRipple(ripple: intensity),
            ]
            FilterImage(with: inputImage, filters: filters, builder: {
                Image(c7Image: $0)
            })
            .frame(idealHeight: R.width-30 / 2 * 3)
            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
            .padding()
            
            Text("Support use filter image with swiftUI")
                .font(.body)
                .textCase(.none)
                .padding(.leading)
                .padding(.trailing)
                .foregroundColor(.black)
            
            VStack(alignment: .leading) {
                Text("Intensity: \(intensity, specifier: "%.2f")")
                Slider(value: $intensity, in: IntensityRange.min...IntensityRange.max)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
            .padding()
        }
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        SwiftUIView()
    }
}
