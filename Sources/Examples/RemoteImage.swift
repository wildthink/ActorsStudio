//
//  RemoteImage.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/11/25.
//

import SwiftUI
import ActorsStudio

struct RemoteImage: View {
//    private let source: URLRequest
    @Resource var image: Image?
//    @Environment(\.dataLoader) private var dataLoader
    let url = URL(string: surl)!
//    init(source: URL) {
//        self.init(source: URLRequest(url: source))
//    }
//
//    init(source: URLRequest) {
//        self.source = source
//    }

    var body: some View {
        ZStack {
            image?.resizable()
//            if let data = data {
//                Data(Data: data)
//            } else {
//                Rectangle().fill(Color.red)
//            }
        }
        .onAppear {
            $image.url = url
            $image.load()
        }
//        .task {
//            image = try? await dataLoader?.fetch(source, builder: Image.init)
//        }
    }
}

let surl = "https://www.pngall.com/wp-content/uploads/8/Sample.png"

#Preview {
    VStack {
        RemoteImage()
            .dataLoader(DataLoader())
        Text("Hello, World!")
    }
    .frame(width: 300, height: 300)
    .padding()
}

#if os(macOS)
public extension Image {
    @Sendable init(data: Data) {
        self = if let it = NSImage(data: data) {
            Self.init(nsImage: it)
        } else {
            Image(systemName: "circle.slash")
        }
    }
}
#endif

#if os(iOS)
public extension Image {
    @Sendable init(data: Data) {
        self = if let it = UIImage(data: data) {
            Self.init(uiImage: it)
        } else {
            Image(systemName: "circle.slash")
        }
    }
}
#endif
