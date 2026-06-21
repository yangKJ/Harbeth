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
            .padding()
            
            if let image = outImage {
                Image(c7Image: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(idealHeight: R.width-30 / 2 * 3)
                    .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
                    .padding()
                
                Text(getFilterDescription())
                    .font(.body)
                    .textCase(.none)
                    .padding(.all, 20)
                    .foregroundColor(.black)
                    .shadow(radius: 20)
            } else {
                Text("loading..")
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
