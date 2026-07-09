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
    public var partyCount: Int { Int(pkhex_save_get_party_count(handle)) }

    public var otName: String {
        get { readNativeString { pkhex_save_get_ot_name(handle, $0, $1) } }
        set { writeNativeString(newValue) { pkhex_save_set_ot_name(handle, $0, $1) } }
    }

    /// Maximum OT name length for this save's generation/language.
    public var maxOTNameLength: Int { Int(pkhex_save_get_max_ot_name_length(handle)) }

    public var tid: UInt16 {
        get { pkhex_save_get_tid(handle) }
        set { pkhex_save_set_tid(handle, newValue) }
    }

    public var sid: UInt16 {
        get { pkhex_save_get_sid(handle) }
        set { pkhex_save_set_sid(handle, newValue) }
    }

    /// 0 = male, 1 = female.
    public var trainerGender: UInt8 {
        get { pkhex_save_get_trainer_gender(handle) }
        set { pkhex_save_set_trainer_gender(handle, newValue) }
    }

    public var money: UInt32 {
        get { pkhex_save_get_money(handle) }
        set { pkhex_save_set_money(handle, newValue) }
    }

    public var maxMoney: Int { Int(pkhex_save_get_max_money(handle)) }

    public var playedHours: Int { Int(pkhex_save_get_played_hours(handle)) }
    public var playedMinutes: Int { Int(pkhex_save_get_played_minutes(handle)) }

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

    public func partySlot(_ index: Int) -> PKM? {
        let pkmHandle = pkhex_save_get_party_slot(handle, Int32(index))
        guard pkmHandle != 0 else { return nil }
        return PKM(handle: pkmHandle)
    }

    public func setPartySlot(_ pkm: PKM, index: Int) {
        _ = pkhex_save_set_party_slot(handle, pkm.handle, Int32(index))
    }

    /// Loads a fresh snapshot of the bag. Edit its pouches, then call `bag.commit(to: self)` to
    /// write the changes back before calling `write()`.
    public func loadBag() -> Bag? {
        let bagHandle = pkhex_bag_load(handle)
        guard bagHandle != 0 else { return nil }
        return Bag(handle: bagHandle)
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
