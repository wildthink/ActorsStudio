//
//  RemoteImage.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/11/25.
//

import SwiftUI
import ActorsStudio

struct RemoteImage: View {
    @Resource var image: Image?
    let url = URL(string: surl)!

    var body: some View {
        ZStack {
            image?
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
        .onAppear {
            $image.url = url
        }
        .task {
//            $image.load()
        }
    }
}

let surl = "https://www.pngall.com/wp-content/uploads/8/Sample.png"

#Preview {
    VStack {
        RemoteImage()
        RemoteImage()
        RemoteImage()
    }
    .resourceLoader(DataLoader())
    .frame(width: 300, height: 300)
    .padding()
}
