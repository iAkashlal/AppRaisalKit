import Foundation

/// Protocol for custom storage implementations
public protocol StorageProvider {
    func save<T: Codable>(_ value: T, forKey key: String) throws
    func load<T: Codable>(forKey key: String) -> T?
    func remove(forKey key: String)
}

/// Default UserDefaults-based storage implementation
public class UserDefaultsStorage: StorageProvider {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    public func save<T: Codable>(_ value: T, forKey key: String) throws {
        let data = try encoder.encode(value)
        userDefaults.set(data, forKey: key)
    }
    
    public func load<T: Codable>(forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else {
            return nil
        }
        return try? decoder.decode(T.self, from: data)
    }
    
    public func remove(forKey key: String) {
        userDefaults.removeObject(forKey: key)
    }
}
