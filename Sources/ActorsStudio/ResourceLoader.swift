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

public actor DataLoader: ResourceLoader, Identifiable {
    
    public enum LoaderStatus {
        case notStarted
        case inProgress(Task<Data, Error>)
        case fetched(Data, Any)
    }
    
    public let id = UUID()
    
    nonisolated(unsafe)
    private var loaders: [URL: LoaderStatus] = [:]
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
        lock.withLock {
            guard case let .fetched(_, value) = loaders[url]
            else { return nil }
            return value as? S
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

        let status = lock.withLock { self.loaders[url] }

        if let status {
            switch status {
                case let .fetched(data, value):
                    return (data as? S) ?? (value as! S)
                case .inProgress(let task):
                    let data = try await task.value
                    return try decode(data)
                case .notStarted:
                    break
            }
        }
        
        if let data = try self.dataFromFileSystem(for: url),
           let value: S = try decode(data) {
            lock.withLock {
                self.loaders[url] = .fetched(data, value)
            }
            return value
        }
        
        let task: Task<Data, Error> = Task {
            let (data, _) = try await urlSession.data(for: URLRequest(url: url))
            try self.persistData(data, for: url)
            return data
        }
        
        lock.withLock {
            loaders[url] = .inProgress(task)
        }
        let data = try await task.value
        let value = try decode(data, as: S.self)
        lock.withLock {
            if let value {
                loaders[url] = .fetched(data, value)
            }
        }
        
        return value
    }
}

// MARK: Cache to/from File
extension DataLoader {
    
    private func dataFromFileSystem(for url: URL) throws -> Data? {
        guard cacheToFile else { return nil }
        
        guard let furl = fileName(for: url) else {
            assertionFailure("Unable to generate a local path for \(url)")
            return nil
        }
        
        let data = try Data(contentsOf: furl)
        return data
    }
    
    private func persistData(_ data: Data, for url: URL) throws {
        guard cacheToFile else { return }
        
        guard let furl = fileName(for: url)
        else {
            assertionFailure("Unable to generate a local path for \(url)")
            return
        }
        
        try data.write(to: furl)
    }
    
    private func fileName(for url: URL) -> URL? {
        guard let fileName = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return applicationSupport.appendingPathComponent(fileName)
    }
}
