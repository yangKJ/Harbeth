//
//  BlendView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/7/29.
//

import SwiftUI
import Harbeth

struct BlendView: View {
    
    @State private var intensity: Float = 0.3
    @State private var blendMode: C7Blend.BlendType = .normal
    @State private var inputImage = R.image("IMG_0020")!
    
    private let blends: [C7Blend.BlendType] = [
        .chromaKey(threshold: 0.3, smoothing: 0.4, color: .black),
        .add,
        .alpha,
        .colorBurn,
        .colorDodge,
        .darken,
        .difference,
        .dissolve,
        .divide,
        .exclusion,
        .hardLight,
        .hue,
        .lighten,
        .linearBurn,
        .luminosity,
        .mask,
        .multiply,
        .normal,
        .overlay,
        .screen,
        .softLight,
        .sourceOver,
        .subtract,
    ]
    
    var body: some View {
        Group {
            switch Result(catching: {
                try setupImage()
            }) {
            case .success(let image):
                VStack {
                    Text("\(blendMode.kernel) filter")
                        .font(.body)
                        .textCase(.uppercase)
                        .padding(.all, 20)
                        //.foregroundColor(.black)
                    
                    Image(c7Image: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(idealHeight: R.width-30 / 2 * 3)
                        .padding()
                    
                    VStack(alignment: .leading) {
                        Picker(blendMode.kernel, selection: $blendMode, content: {
                            ForEach(self.blends) { mode in
                                Text(mode.kernel).tag(mode)
                            }
                        })
                        .blendModesPickerStyle()
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.background, lineWidth: 2))
                        
                        VStack(alignment: .leading) {
                            Text("Intensity: \(intensity, specifier: "%.2f")")
                            Slider(value: $intensity, in: R.iRange.min...R.iRange.max)
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
                    }
                    .padding()
                }
            case .failure(let error):
                Text(error.localizedDescription)
            }
        }
        .padding(.bottom)
        .toolbar(content: { Spacer() })
    }
    
    private func setupImage() throws -> C7Image {
        let overTexture = try! Res.rgUVB1Gradient(CGSize(width: 420, height: 270))
        var filter = C7Blend(with: blendMode, blendTexture: overTexture)
        filter.intensity = intensity
        let dest = HarbethIO(element: inputImage, filter: filter)
        return try dest.output()
    }
}

struct BlendView_Previews: PreviewProvider {
    static var previews: some View {
        BlendView()
    }
}

extension Picker {
    func blendModesPickerStyle() -> some View {
        #if os(iOS)
        return self.pickerStyle(WheelPickerStyle())
        #elseif os(macOS)
        return self.pickerStyle(MenuPickerStyle())
                .scaledToFit()
                .padding()
                .largeControlSize()
        #endif
    }
}
