//
//  DataLoader.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/11/25.
//

import Foundation
import SwiftUI

public protocol ResourceLoader {
    func peek<S>(_ url: URL, as type: S.Type) -> S?
    func fetch<S: Sendable>(
        _ url: URL, as: S.Type) async throws -> S?
}

public actor DataLoader: ResourceLoader {
    
    private enum LoaderStatus {
        case inProgress(Task<Data, Error>)
        case fetched(Data, Any)
    }
    
    nonisolated(unsafe) private var loaders: [URLRequest: LoaderStatus] = [:]
    private let lock = NSLock()
    private var decoders: [DataDecoder]
    
    public let cacheToFile = false
    var urlSession: URLSession
    
    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        decoders = [
        ]
    }
    
    // MARK: Synchronously peek for an available value
    nonisolated
    public func peek<S>(_ url: URL, as type: S.Type = S.self) -> S? {
        peek(URLRequest(url: url), as: type)
    }
    
    nonisolated
    public func peek<S>(
        _ urlRequest: URLRequest,
        as type: S.Type = S.self
    ) -> S? {
        lock.withLock {
            guard case let .fetched(data, value) = loaders[urlRequest]
            else { return nil }
            return (data as? S) ?? (value as? S)
        }
    }
    
    // MARK: Handle Decoding from Data
    
    func decode<T>(
        _ data: Data,
        as type: T.Type = T.self
    ) throws -> T? {
        func dcode<D>(_ t: D.Type) throws -> D? {
            try _decode(data, as: D.self)
        }
        if let opt = T.self as? AnyOptional.Type {
            return try _openExistential(opt.wrappedType, do: dcode) as? T
        } else {
            return try _decode(data, as: T.self)
        }
    }
    
    func _decode<T>(
        _ data: Data,
        as type: T.Type = T.self
    ) throws -> T? {
        switch T.self {
            case is Image.Type:
                Image(data: data) as? T
            case is Image.Type?:
                Image(data: data) as? T
            case let dc as Decodable.Type:
                try JSONDecoder().decode(dc, from: data) as? T
            default:
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: "Unsupported decoding type \(T.self)"))
        }
    }
    
    // MARK: Fetch a value
    public func fetch<S: Sendable>(
        _ url: URL,
        as t: S.Type = S.self
    ) async throws -> S? {
        try await fetch(URLRequest(url: url), as: t)
    }
    
    public func fetch<S: Sendable>(
        _ urlRequest: URLRequest,
        as t: S.Type = S.self
    ) async throws -> S? {
        let status = lock.withLock { self.loaders[urlRequest] }
        if let status {
            switch status {
                case let .fetched(data, value):
                    return (data as? S) ?? (value as! S)
                case .inProgress(let task):
                    let data = try await task.value
                    return try decode(data)
            }
        }
        
        if let data = try self.dataFromFileSystem(for: urlRequest),
           let value: S = try decode(data) {
            lock.withLock {
                self.loaders[urlRequest] = .fetched(data, value)
            }
            return value
        }
        
        let task: Task<Data, Error> = Task {
            let (data, _) = try await urlSession.data(for: urlRequest)
            try self.persistData(data, for: urlRequest)
            return data
        }
        
        lock.withLock {
            loaders[urlRequest] = .inProgress(task)
        }
        let data = try await task.value
        let value = try decode(data, as: S.self)
        lock.withLock {
            if let value {
                loaders[urlRequest] = .fetched(data, value)
            }
        }
        
        return value
    }
}

// MARK: Cache to/from File
extension DataLoader {
    
    private func dataFromFileSystem(for urlRequest: URLRequest) throws -> Data? {
        guard cacheToFile else { return nil }
        
        guard let url = fileName(for: urlRequest) else {
            assertionFailure("Unable to generate a local path for \(urlRequest)")
            return nil
        }
        
        let data = try Data(contentsOf: url)
        return data
    }
    
    private func persistData(_ data: Data, for urlRequest: URLRequest) throws {
        guard cacheToFile else { return }
        
        guard let url = fileName(for: urlRequest)
        else {
            assertionFailure("Unable to generate a local path for \(urlRequest)")
            return
        }
        
        try data.write(to: url)
    }
    
    private func fileName(for urlRequest: URLRequest) -> URL? {
        guard let fileName = urlRequest.url?.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return applicationSupport.appendingPathComponent(fileName)
    }
}
