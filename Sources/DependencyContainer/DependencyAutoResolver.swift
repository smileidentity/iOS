import Foundation

class DependencyAutoResolver {

    private static var instance: DependencyResolver = DependencyContainer.shared

    static func has<T>(_ dependency: T.Type) -> Bool {
        return instance.has(dependency)
    }

    static func resolve<T>(_ dependency: T.Type) -> T {
        return instance.resolve(dependency)
    }

    static func set(resolver: DependencyResolver) {
        instance = resolver
    }

    static func reset() {
        instance = DependencyContainer.shared
    }
}
