struct CommentStripper {
    private(set) var inBlockComment: Bool = false

    mutating func strip(_ line: String) -> String {
        var result = ""
        let chars = Array(line)
        var i = 0

        while i < chars.count {
            if inBlockComment {
                if i + 1 < chars.count && chars[i] == "-" && chars[i + 1] == "]" {
                    inBlockComment = false
                    i += 2
                } else {
                    i += 1
                }
            } else {
                if i + 1 < chars.count && chars[i] == "-" && chars[i + 1] == "-" {
                    break
                }
                if i + 1 < chars.count && chars[i] == "[" && chars[i + 1] == "-" {
                    inBlockComment = true
                    i += 2
                    continue
                }
                result.append(chars[i])
                i += 1
            }
        }

        return result
    }
}
