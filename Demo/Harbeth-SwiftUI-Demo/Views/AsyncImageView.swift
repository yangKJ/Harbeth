//
//  AsyncImageView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/7/29.
//

import SwiftUI
import Harbeth
import Combine

struct AsyncImageView: View {
    
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
                
                Text("Async transmit output image")
                    .font(.body)
                    .textCase(.none)
                    .padding(.all, 20)
                    .foregroundColor(.black)
            } else {
                Text("loading..")
            }
        }
        .onAppear(perform: setupImage)
    }
    
    func setupImage() {
        let filters: [C7FilterProtocol] = [
            //C7Pixellated(scale: 0.04),
            CILookupTable(cubeName: "violet", amount: 0.5),
            CIGaussianBlur(radius: 5),
            C7Flip(horizontal: true, vertical: false),
            C7SplitScreen(type: .two, direction: .vertical),
        ]
        let inputImage = R.image("IMG_0020")!
        let dest = BoxxIO(element: inputImage, filters: filters)
        dest.transmitOutput { img in
            DispatchQueue.main.async {
                self.outImage = img
            }
        }
    }
}

struct AsyncImageView_Previews: PreviewProvider {
    static var previews: some View {
        AsyncImageView()
    }
}
