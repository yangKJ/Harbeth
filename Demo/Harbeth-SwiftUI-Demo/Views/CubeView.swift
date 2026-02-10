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
    
    enum ImplementationType {
        case coreImage
        case metal
    }
    
    @State private var outImage: C7Image?
    @State private var selectedCube: CubeType = .violet
    @State private var selectedImplementation: ImplementationType = .metal
    
    var body: some View {
        VStack {
            Picker("CUBE File", selection: $selectedCube) {
                Text("Violet").tag(CubeType.violet)
                Text("Vista200").tag(CubeType.vista200)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            Picker("Implementation", selection: $selectedImplementation) {
                Text("CoreImage").tag(ImplementationType.coreImage)
                Text("Metal").tag(ImplementationType.metal)
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
        .onChange(of: selectedImplementation) { _ in setupImage() }
    }
    
    func getFilterDescription() -> String {
        switch (selectedCube, selectedImplementation) {
        case (.violet, .coreImage):
            return "CoreImage Violet CUBE filtered image"
        case (.violet, .metal):
            return "Metal Violet CUBE filtered image"
        case (.vista200, .coreImage):
            return "CoreImage Vista200 CUBE filtered image"
        case (.vista200, .metal):
            return "Metal Vista200 CUBE filtered image"
        }
    }
    
    func setupImage() {
        let inputImage = R.image("IMG_0020")!
        let cubeName = selectedCube == .violet ? "violet" : "vista200 v1"
        
        var filter: C7FilterProtocol
        
        switch selectedImplementation {
        case .coreImage:
            filter = CIColorCube(cubeName: cubeName)
        case .metal:
            filter = C7ColorCube(cubeName: cubeName)
        }
        
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
