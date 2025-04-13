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
    @Environment(\.resourceLoader) private var resourceLoader
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
        tracker.cache = resourceLoader
        tracker.url = url
    }
    public var projectedValue: Tracker<Value> {
        tracker
    }
}

// MARK: Environment Hook
public extension EnvironmentValues {
    @Entry var resourceLoader: ResourceLoader = DataLoader()
}

public extension View {
    func resourceLoader(_ cache: ResourceLoader) -> some View {
        environment(\.resourceLoader, cache)
    }
}

extension Resource {
    
    @MainActor
    public final class Tracker<BoxValue: Sendable>: ObservableObject {
        var cache: ResourceLoader?
        public var value: BoxValue?
        public var url: URL? {
            didSet { load() }
        }
                
        init(cacheKey: URL? = nil) {
            self.url = cacheKey
        }
        
        func report(error: Error) {
            if let url {
                print("Error loading \(BoxValue.self)\n\tFrom \(url)\n\t: \(error.localizedDescription)")
            } else {
                print("Error loading \(BoxValue.self)\n\t: \(error.localizedDescription)")
            }
        }
        
        func resetCache(with value: BoxValue) {
            task?.cancel()
            task = nil
            objectWillChange.send()
            self.value = value
        }
        
        var task: Task<Void, Never>?
        
        public func load() {
            guard let cache, let url, task == nil
            else { return }
            
            task = Task {
                do {
                    if let value = try await cache.fetch(url, as: BoxValue.self) {
                        resetCache(with: value)
                    }
                } catch {
                    report(error: error)
                }
            }
        }
    }
}
