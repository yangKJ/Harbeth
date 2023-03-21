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
        var img = R.image("IMG_0020")!
        let filter1 = C7SoulOut(soul: 0.25)
        let filter2 = C7Storyboard(ranks: 3)
        img = img ->> filter1 ->> filter2
        let image = Image(uiImage: img)
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
