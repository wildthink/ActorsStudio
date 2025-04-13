//
//  AnyOptional.swift
//  ActorsStudio
//
//  Created by Jason Jobe on 4/12/25.
//


protocol AnyOptional {
    static var wrappedType: Any.Type { get }
    var wrapped: Any? { get }
}

extension Optional: AnyOptional {
    static var wrappedType: Any.Type { Wrapped.self }
    
    var wrapped: Any? {
        switch self {
            case let .some(value):
                return value
            case .none:
                return nil
        }
    }
}
