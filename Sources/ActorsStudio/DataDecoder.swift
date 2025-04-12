//
//  DataDecoder.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/12/25.
//


import Foundation

public struct DataDecoder<Value: Sendable>: Sendable {
    public typealias Value = Value
    public typealias Decoder = @Sendable (Data) throws -> Value
    
    let _decode: Decoder

    init(decoder: @escaping Decoder) {
        self._decode = decoder
    }
    
    func decode(_ data: Data) throws -> Value {
        try _decode(data)
    }
}

public extension DataDecoder where Value: Sendable & Decodable {
    static var decodable: DataDecoder {
        DataDecoder { try JSONDecoder().decode(Value.self, from: $0) }
    }
}
