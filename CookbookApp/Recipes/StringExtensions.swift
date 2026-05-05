import Foundation

extension String {
    var sentenceCased: String {
        guard let firstChar = first else { return self }
        return firstChar.uppercased() + dropFirst()
    }
}
