//
//  ContentView.swift
//  Harbeth-SwiftUI-Demo
//
//  Created by Condy on 2023/3/21.
//

import SwiftUI
import Harbeth

struct ContentView: View {
    
    var __image: Image = {
        let img = R.image("IMG_0020")!
        let filter1 = C7SoulOut(soul: 0.25)
        let dest = BoxxIO(element: img, filters: [filter1])
        let outImg = (try? dest.output()) ?? img
        let image = Image(uiImage: outImg)
        //let image = Image(systemName: "globe")
        return image
    }()
    
    var body: some View {
        VStack {
            __image
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: UIScreen.main.bounds.width-30)
                .foregroundColor(.accentColor)
            Text("Hello word!")
                .padding(.all, 10)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
