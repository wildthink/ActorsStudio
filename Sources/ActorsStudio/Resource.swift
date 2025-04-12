//
//  ResourceProvider.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/11/25.
//


//
//  Resource.swift
//
//  Created by Jason Jobe on 1/2/25.
//
// https://www.alihilal.com/blog/zero-copy-swift-mastering-accessor-coroutines.mdx/
import Foundation
import SwiftUI


@MainActor
@propertyWrapper
public struct Resource<Value: Sendable>: @preconcurrency DynamicProperty
{
    @Environment(\.dataLoader) private var dataLoader
    @StateObject private var tracker: Tracker<Value> = .init()
    var url: URL?
    
    public var wrappedValue: Value {
        tracker.value ?? _wrappedValue
    }
    
    var _wrappedValue: Value
    
    public init(wrappedValue: Value) {
        self._wrappedValue = wrappedValue
    }
    
    public func update() {
        tracker.cache = dataLoader
        tracker.url = url
    }
    public var projectedValue: Tracker<Value> {
        tracker
    }
}

// MARK: Environment Hook
public extension EnvironmentValues {
    @Entry var dataLoader: DataLoader?
}

public extension View {
    func dataLoader(_ cache: DataLoader) -> some View {
        environment(\.dataLoader, cache)
    }
}

extension Resource {
    
    @MainActor
    public final class Tracker<BoxValue: Sendable>: ObservableObject {
        var cache: DataLoader?
        public var value: BoxValue?
        public var url: URL? {
            didSet { load() }
        }
                
        init(cacheKey: URL? = nil) {
            self.url = cacheKey
        }
        
        func report(error: Error) {
            guard let url else { return }
            print("Error loading \(url)\n\t: \(error.localizedDescription)")
        }
        
        func resetCache(with value: BoxValue) {
            objectWillChange.send()
            self.value = value
        }
        
        public func load() {
            guard let cache, let url else { return }

            if let resource = cache.peek(url, as: BoxValue.self) {
                resetCache(with: resource)
            }
            
            Task {
                do {
                    let value: BoxValue = try await cache.fetch(url) { _ in
                        fatalError()
                    }
                    resetCache(with: value)
                } catch {
                    report(error: error)
                }
            }
        }
    }
}
