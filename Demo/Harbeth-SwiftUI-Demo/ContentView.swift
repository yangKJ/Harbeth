//
//  ContentView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI
import Harbeth

struct ContentView: View {
    
    @State private var intensity: Float = 0.3
    @State private var blendMode: C7Blend.BlendType = .normal
    @State private var inputImage = R.image("AX")!
    @State private var overTexture = try! DefTexture.rgUVB1Gradient(CGSize(width: 420, height: 270))
    
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
                        .foregroundColor(.black)
                    
                    Image(c7Image: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: R.width-30)
                    
                    VStack(alignment: .leading) {
                        Picker(blendMode.kernel, selection: $blendMode, content: {
                            ForEach(self.blends) { mode in
                                Text(mode.kernel).tag(mode)
                            }
                        })
                        .blendModesPickerStyle()
                        .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
                        
                        VStack(alignment: .leading) {
                            Text("Intensity: \(intensity, specifier: "%.2f")")
                            Slider(value: $intensity, in: IntensityRange.min...IntensityRange.max)
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
        var filter = C7Blend(with: blendMode, blendTexture: overTexture)
        filter.intensity = intensity
        let dest = BoxxIO(element: inputImage, filter: filter)
        return try dest.output()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct DefTexture {
    public static func rgUVB1Gradient(_ size: CGSize = .onePixel) throws -> MTLTexture {
        let texture = BoxxIO<Any>.destTexture(width: Int(size.width), height: Int(size.height))
        let filter = C7ColorGradient(with: .rgUVB1)
        var dest = BoxxIO(element: texture, filter: filter)
        dest.createDestTexture = false
        return try dest.output()
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

extension View {
    func largeControlSize() -> some View {
        #if os(macOS)
        return self.controlSize(.large)
        #else
        return self
        #endif
    }
}

extension Color {
    static var background: Color {
        #if os(iOS)
        return Color(UIColor.secondarySystemBackground)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        #error("Unsupported Platform")
        #endif
    }
}
