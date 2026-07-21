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
    @State private var inputImage = R.image("Bear")!
    
    private let blends: [C7Blend.BlendType] = [
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
                    Image(c7Image: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading) {
                        Picker(blendMode.kernel, selection: $blendMode, content: {
                            ForEach(self.blends) { mode in
                                Text(mode.kernel).tag(mode)
                            }
                        })
                        .blendModesPickerStyle()
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        
                        VStack(alignment: .leading) {
                            Text("Intensity: \(intensity, specifier: "%.2f")").foregroundColor(.white.opacity(0.94))
                            Slider(value: $intensity, in: R.iRange.min...R.iRange.max).accentColor(Color(hex: "#5E9EFF"))
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
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
        let overTexture = try Res.rgUVB1Gradient(CGSize(width: 420, height: 270))
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
    @MainActor
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



// MARK: - Design System Colors (synced with ContentView)
private extension View {
    var dsSurfaceGlass: Color { Color.white.opacity(0.06) }
    var dsSurfaceCard: Color { Color(hex: "#141418") }
    var dsBackground: Color { Color(hex: "#0A0A0C") }
    var dsBorderSubtle: Color { Color.white.opacity(0.06) }
    var dsBorderActive: Color { Color.white.opacity(0.14) }
    var dsTextPrimary: Color { Color.white.opacity(0.94) }
    var dsTextSecondary: Color { Color.white.opacity(0.62) }
    var dsTextTertiary: Color { Color.white.opacity(0.38) }
}

private let dsAccentPrimary = Color(hex: "#5E9EFF")
private let dsAccentSecondary = Color(hex: "#A78BFA")
private let dsAccentSuccess = Color(hex: "#34D399")
