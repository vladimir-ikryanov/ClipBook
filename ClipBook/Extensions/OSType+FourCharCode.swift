import Carbon

extension OSType {
    nonisolated init(_ string: String) {
        var bytes = Array(string.utf8.prefix(4))
        if bytes.count < 4 {
            bytes.append(contentsOf: repeatElement(UInt8(0x20), count: 4 - bytes.count))
        }
        self = bytes.reduce(0) { ($0 << 8) | OSType($1) }
    }
}
