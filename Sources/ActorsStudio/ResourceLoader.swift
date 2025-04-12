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
    
    nonisolated(unsafe) private var datas: [URLRequest: LoaderStatus] = [:]
    private let lock = NSLock()
    
    public let cacheToFile = false
    
    nonisolated
    public func peek<S: Sendable>(_ url: URL, as type: S.Type = S.self) -> S? {
        lock.withLock {
            guard case let .fetched(data, value) = datas[URLRequest(url: url)]
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
        let status = lock.withLock { self.datas[urlRequest] }
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
                self.datas[urlRequest] = .fetched(data, value)
            }
            return value
        }
        
        let task: Task<Data, Error> = Task {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            try self.persistData(data, for: urlRequest)
            return data
        }
        
        lock.withLock {
            datas[urlRequest] = .inProgress(task)
        }
        let data = try await task.value
        let value = try builder(data)
        lock.withLock {
            datas[urlRequest] = .fetched(data, value)
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

// MARK:
import SwiftUI

extension EnvironmentValues {
    @Entry var dataLoader: DataLoader?
}

struct RemoteImage: View {
    private let source: URLRequest
    @State private var image: Image?

    @Environment(\.dataLoader) private var dataLoader

    init(source: URL) {
        self.init(source: URLRequest(url: source))
    }

    init(source: URLRequest) {
        self.source = source
    }

    var body: some View {
        Group {
//            if let data = data {
//                Data(Data: data)
//            } else {
                Rectangle()
                    .background(Color.red)
//            }
        }
        .task {
            let it = try? await dataLoader?.fetch(source) { data in
                Image("")
            }
            await loadData(at: source)
        }
    }

    func loadData(at source: URLRequest) async {
        do {
            let it = try await dataLoader?.fetch(source) { data in
                Image("")
//                image = Image(uiImage: CGImage(data: $0)!)
            }
        } catch {
            print(error)
        }
    }
}

extension Data: Sendable {}
