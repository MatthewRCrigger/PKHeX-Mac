import CPKHeXNative
import Foundation

public enum PKHeXError: Error {
    case unrecognizedSaveFile
    case writeFailed
}

/// A cross-generation conversion (see `SaveFile.convertForTransfer`) that has no legal path — wrong
/// direction, incompatible species/form, or a GB-era language mismatch. `message` matches
/// PKHeX.WinForms' wording so it can be shown to the user as-is.
public struct PKMConversionError: Error {
    public let message: String
}

/// Wraps a loaded save file handle from PKHeX.Native. Closes the underlying handle on dealloc.
public final class SaveFile {
    let handle: Int64

    public let boxCount: Int
    public let boxSlotCount: Int
    public let generation: UInt8
    /// Display name of this save's game version, e.g. "Crystal", "Platinum", "HeartGold".
    public let gameName: String
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

    public var maxSpeciesID: Int { Int(pkhex_save_get_max_species_id(handle)) }
    public var dexSeenCount: Int { Int(pkhex_save_get_dex_seen_count(handle)) }
    public var dexCaughtCount: Int { Int(pkhex_save_get_dex_caught_count(handle)) }
    public var hasPokedex: Bool { pkhex_save_has_pokedex(handle) == 1 }

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
        self.gameName = readNativeString { pkhex_save_get_game_name(handle, $0, $1) }
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

    /// Clears a box slot back to empty. Other slots are unaffected (box slots may have gaps).
    public func clearSlot(box: Int, slot: Int) {
        _ = pkhex_save_clear_slot(handle, Int32(box), Int32(slot))
    }

    public func partySlot(_ index: Int) -> PKM? {
        let pkmHandle = pkhex_save_get_party_slot(handle, Int32(index))
        guard pkmHandle != 0 else { return nil }
        return PKM(handle: pkmHandle)
    }

    public func setPartySlot(_ pkm: PKM, index: Int) {
        _ = pkhex_save_set_party_slot(handle, pkm.handle, Int32(index))
    }

    /// Clears a party slot. Unlike box slots, every following party member slides down one slot
    /// so the party stays contiguous from index 0 (matching how the party is actually read by the
    /// game — there's no such thing as a "gap" in the middle of a party).
    public func clearPartySlot(_ index: Int) {
        _ = pkhex_save_clear_party_slot(handle, Int32(index))
    }

    /// Display name for the given box (0-indexed), e.g. "Box 1" or a custom name if this save
    /// format supports them.
    public func boxName(_ box: Int) -> String {
        readNativeString { pkhex_save_get_box_name(handle, Int32(box), $0, $1) }
    }

    /// Number of occupied slots in the given box (0-indexed). Box slots may have gaps, so this
    /// counts non-empty slots rather than assuming they're packed from index 0.
    public func boxOccupiedSlotCount(_ box: Int) -> Int {
        (0..<boxSlotCount).reduce(0) { count, slotIndex in
            self.slot(box: box, slot: slotIndex) != nil ? count + 1 : count
        }
    }

    /// Creates a new blank-template Pokemon of the given species (level 1, this save's trainer
    /// info), for inserting into an empty slot via `setSlot`/`setPartySlot`. Returns nil if the
    /// species is out of range for this save's generation.
    public func createBlankPKM(species: UInt16) -> PKM? {
        let pkmHandle = pkhex_save_create_blank_pkm(handle, species)
        guard pkmHandle != 0 else { return nil }
        return PKM(handle: pkmHandle)
    }

    /// Converts a PKM from another (possibly different-generation) save into the format this save
    /// requires, ready for `setSlot`/`setPartySlot` — e.g. dragging a Gen 3 Pokemon into a Gen 4
    /// save's box. Returns `.failure` with a human-readable reason (matching PKHeX.WinForms'
    /// wording) if no legal conversion path exists: wrong direction, incompatible species/form, or
    /// a GB-era (Gen 1/2) language mismatch. Same-generation transfers always succeed here too, so
    /// callers don't need to special-case "same format" themselves.
    public func convertForTransfer(_ pkm: PKM) -> Result<PKM, PKMConversionError> {
        let convertedHandle = pkhex_pkm_convert_to_save(pkm.handle, handle)
        guard convertedHandle != 0 else {
            let message = readNativeString { pkhex_pkm_get_convert_error(pkm.handle, handle, $0, $1) }
            return .failure(PKMConversionError(message: message.isEmpty ? "This Pokémon can't be transferred to this save." : message))
        }
        return .success(PKM(handle: convertedHandle))
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
