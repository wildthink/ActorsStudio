//
//  DataDecoder.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/12/25.
//


import Foundation

public struct DataDecoder: Sendable {

    let valueType: Any.Type
    let _decode: @Sendable (Data) throws -> Any

    init<S>(decoder: @escaping @Sendable (Data) throws -> S) {
        self._decode = decoder
        self.valueType = S.self
    }
    
    func decode<S>(_ data: Data) throws -> S {
       guard let it = try _decode(data) as? S
       else {
           throw DataDecoderError.failedToDecode(valueType)
       }
       return it
    }
}

public enum DataDecoderError: Error {
    case failedToDecode(Any.Type)
}

import SwiftUI

#if os(macOS)
import AppKit
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
import UIKit

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
