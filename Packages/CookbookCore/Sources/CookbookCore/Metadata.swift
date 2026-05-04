import Foundation

public struct Metadata: Sendable {
    private let storage: [(key: String, value: String)]

    public init(_ entries: [(key: String, value: String)] = []) {
        self.storage = entries
    }

    public subscript(key: String) -> String? {
        storage.first { $0.key == key }?.value
    }

    public var servings: [Int]? {
        guard let raw = self["servings"] else { return nil }
        let parts = raw
            .components(separatedBy: CharacterSet(charactersIn: ",").union(.whitespaces))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let ints = parts.compactMap(Int.init)
        return ints.isEmpty ? nil : ints
    }

    public var title: String? {
        self["title"]
    }

    public var tags: [String] {
        guard let raw = self["tags"] else { return [] }
        return raw
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    public var allEntries: [(key: String, value: String)] {
        storage
    }
}

extension Metadata: Equatable {
    public static func == (lhs: Metadata, rhs: Metadata) -> Bool {
        guard lhs.storage.count == rhs.storage.count else { return false }
        return zip(lhs.storage, rhs.storage).allSatisfy { $0.key == $1.key && $0.value == $1.value }
    }
}
