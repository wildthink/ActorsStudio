//
//  Promise.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/8/25.
//


import Foundation

//extension Task {
public func synchronize<T: Sendable>(
    timeout: TimeInterval = 10.0,
    work: @Sendable @escaping () async throws -> T
) throws -> T {
    let promise = Promise<T>()
    
    Task<Void, Never> {
        do {
            let result = try await work()
            promise.fulfill(result)
        } catch {
            promise.reject(error)
        }
    }
    return try promise.wait(timeout: timeout)
}

public func synchronize<T: Sendable>(
    timeout: TimeInterval = 10.0,
    work: @Sendable @escaping () async -> T
) throws -> T {
    let promise = Promise<T>()
    
    Task<Void, Never> {
        let result = await work()
        promise.fulfill(result)
    }
    return try promise.wait(timeout: timeout)
}

final class Promise<T: Sendable>: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var result: Result<T, Error>?
    
    func fulfill(_ value: T) {
        lock.withLock {
            result = .success(value)
        }
        semaphore.signal()
    }
    
    func reject(_ error: Error) {
        lock.withLock {
            result = .failure(error)
        }
        semaphore.signal()
    }
    
    func wait(timeout: TimeInterval) throws -> T {
        _ = semaphore.wait(timeout: .now() + timeout)
        lock.lock()
        defer { lock.unlock() }
        guard let result = result else {
            throw NSError(domain: "PromiseError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timeout occurred"])
        }
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }
}
