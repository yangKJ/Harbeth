//
//  CubeView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/5.
//

import SwiftUI
import Harbeth

struct CubeView: View {
    enum CubeType {
        case violet
        case vista200
    }

    @State private var outImage: C7Image?
    @State private var selectedCube: CubeType = .violet

    var body: some View {
        VStack {
            Picker("CUBE File", selection: $selectedCube) {
                Text("Violet").tag(CubeType.violet)
                Text("Vista200").tag(CubeType.vista200)
            }
            .pickerStyle(SegmentedPickerStyle())
            .accentColor(Color(hex: "#5E9EFF"))
            .padding()

            if let image = outImage {
                Image(c7Image: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.06)))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                    .padding()

                Text(getFilterDescription())
                    .font(.body)
                    .textCase(.none)
                    .padding(.all, 20)
                    .foregroundColor(.white.opacity(0.94))

            } else {
                Text("loading..").foregroundColor(.white.opacity(0.62))
            }
        }
        .onAppear(perform: setupImage)
        .onChange(of: selectedCube) { _ in setupImage() }
    }

    func getFilterDescription() -> String {
        switch selectedCube {
        case .violet:
            return "Metal Violet CUBE filtered image"
        case .vista200:
            return "Metal Vista200 CUBE filtered image"
        }
    }

    func setupImage() {
        let inputImage = R.image("IMG_0020")!
        let cubeName = selectedCube == .violet ? "violet" : "vista200 v1"

        let filter = C7ColorCube(cubeName: cubeName)
        let dest = HarbethIO(element: inputImage, filter: filter)
        dest.transmitOutput { img in
            DispatchQueue.main.async {
                self.outImage = img
            }
        }
    }
}

struct CubeView_Previews: PreviewProvider {
    static var previews: some View {
        CubeView()
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
