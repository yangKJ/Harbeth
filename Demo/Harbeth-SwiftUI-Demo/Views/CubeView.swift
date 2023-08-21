//
//  CubeView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/8/5.
//

import SwiftUI
import Harbeth

struct CubeView: View {
    @State private var outImage: C7Image?
    
    var body: some View {
        VStack {
            if let image = outImage {
                Image(c7Image: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(idealHeight: R.width-30 / 2 * 3)
                    .background(RoundedRectangle(cornerRadius: 10).foregroundColor(Color.background))
                    .padding()
                
                Text("CI color cube filtered image")
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
    }
    
    func setupImage() {
        let inputImage = R.image("IMG_0020")!
        let filter = CIColorCube(cubeName: "vista200 v1")
        let dest = BoxxIO(element: inputImage, filter: filter)
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
