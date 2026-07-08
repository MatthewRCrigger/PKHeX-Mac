import Foundation

/// Calls a size-then-fill UTF-16 native accessor and decodes the result as a Swift String.
func readNativeString(_ call: (UnsafeMutablePointer<UInt16>?, Int32) -> Int32) -> String {
    let requiredLength = call(nil, 0)
    guard requiredLength > 0 else { return "" }

    var buffer = [UInt16](repeating: 0, count: Int(requiredLength))
    let written = buffer.withUnsafeMutableBufferPointer { ptr in
        call(ptr.baseAddress, Int32(ptr.count))
    }
    guard written == requiredLength else { return "" }
    return String(utf16CodeUnits: buffer, count: buffer.count)
}

/// Converts a Swift String to a UTF-16 buffer and calls a native setter accessor with it.
func writeNativeString(_ value: String, _ call: (UnsafePointer<UInt16>?, Int32) -> Void) {
    var utf16 = Array(value.utf16)
    utf16.withUnsafeBufferPointer { ptr in
        call(ptr.baseAddress, Int32(ptr.count))
    }
}
