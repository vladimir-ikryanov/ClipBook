import Carbon

extension OSType {
    init(_ string: String) {
        self = string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}
