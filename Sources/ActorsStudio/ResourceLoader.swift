//
//  DataLoader.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/11/25.
//

import Foundation


public actor DataLoader {
    
    private enum LoaderStatus {
        case inProgress(Task<Data, Error>)
        case fetched(Data, Sendable)
    }
    
    nonisolated(unsafe) private var loaders: [URLRequest: LoaderStatus] = [:]
    private let lock = NSLock()
    private var decoders: [Any.Type : any DataDecoder]
    
    public let cacheToFile = false
    var urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }
    
    nonisolated
    public func peek<S: Sendable>(_ url: URL, as type: S.Type = S.self) -> S? {
        peek(URLRequest(url: url), as: type)
    }
    
    nonisolated
    public func peek<S: Sendable>(
        _ urlRequest: URLRequest,
        as type: S.Type = S.self
    ) -> S? {
        lock.withLock {
            guard case let .fetched(data, value) = loaders[urlRequest]
            else { return nil }
            return (data as? S) ?? (value as? S)
        }
    }
    
    public func fetch<S: Sendable>(
        _ url: URL,
        builder: @Sendable @escaping (Data) throws -> S
    ) async throws -> S {
        try await fetch(URLRequest(url: url), builder: builder)
    }
        
    public func fetch<S: Sendable>(
        _ urlRequest: URLRequest,
        builder: @Sendable @escaping (Data) throws -> S
    ) async throws -> S {
        let status = lock.withLock { self.loaders[urlRequest] }
        if let status {
            switch status {
            case let .fetched(data, value):
                return (data as? S) ?? (value as! S)
            case .inProgress(let task):
                let data = try await task.value
                return try builder(data)
            }
        }
        
        if let data = try self.dataFromFileSystem(for: urlRequest) {
            let value = try builder(data)
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
        let value = try builder(data)
        lock.withLock {
            loaders[urlRequest] = .fetched(data, value)
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
