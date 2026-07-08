import CPKHeXNative
import Foundation

public enum PKHeXError: Error {
    case unrecognizedSaveFile
    case writeFailed
}

/// Wraps a loaded save file handle from PKHeX.Native. Closes the underlying handle on dealloc.
public final class SaveFile {
    let handle: Int64

    public let boxCount: Int
    public let boxSlotCount: Int
    public let generation: UInt8

    public init(data: Data) throws {
        let handle: Int64 = data.withUnsafeBytes { rawBuffer in
            let base = rawBuffer.bindMemory(to: UInt8.self).baseAddress
            return pkhex_save_load(base, Int32(rawBuffer.count))
        }
        guard handle != 0 else { throw PKHeXError.unrecognizedSaveFile }

        self.handle = handle
        self.boxCount = Int(pkhex_save_get_box_count(handle))
        self.boxSlotCount = Int(pkhex_save_get_box_slot_count(handle))
        self.generation = pkhex_save_get_generation(handle)
    }

    deinit {
        pkhex_save_close(handle)
    }

    public func slot(box: Int, slot: Int) -> PKM? {
        let pkmHandle = pkhex_save_get_slot(handle, Int32(box), Int32(slot))
        guard pkmHandle != 0 else { return nil }
        return PKM(handle: pkmHandle)
    }

    public func setSlot(_ pkm: PKM, box: Int, slot: Int) {
        _ = pkhex_save_set_slot(handle, pkm.handle, Int32(box), Int32(slot))
    }

    /// Serializes the save (with checksums fixed up) back to bytes ready to write to disk.
    public func write() throws -> Data {
        let requiredLength = pkhex_save_write(handle, nil, 0)
        guard requiredLength > 0 else { throw PKHeXError.writeFailed }

        var buffer = [UInt8](repeating: 0, count: Int(requiredLength))
        let written = buffer.withUnsafeMutableBufferPointer { ptr in
            pkhex_save_write(handle, ptr.baseAddress, Int32(ptr.count))
        }
        guard written == requiredLength else { throw PKHeXError.writeFailed }
        return Data(buffer)
    }
}
