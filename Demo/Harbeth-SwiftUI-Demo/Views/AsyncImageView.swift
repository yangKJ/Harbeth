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
    
    @StateObject var dest = AsyncDest<C7Image>()
    
    var body: some View {
        VStack {
            if let image = dest.bookmarks {
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
                    //.foregroundColor(.black)
            } else if let error = dest.error {
                Text(error.localizedDescription)
            } else {
                Text("loading..")
            }
        }
        .overlay(alignment: .top) {
            if dest.error != nil {
                ErrorView(error: $dest.error)
            }
        }
        .task {
            let filters: [C7FilterProtocol] = [
                C7Pixellated(scale: 0.02),
                CILookupTable(cubeName: "violet", amount: 0.5),
                CIGaussianBlur(radius: 5),
                C7Flip(horizontal: true, vertical: false),
                //C7SplitScreen(type: .two, direction: .vertical),
            ]
            let inputImage = R.image("IMG_0020")!
            await dest.output(with: inputImage, filters: filters)
        }
    }
}

struct AsyncImageView_Previews: PreviewProvider {
    static var previews: some View {
        AsyncImageView()
    }
}
