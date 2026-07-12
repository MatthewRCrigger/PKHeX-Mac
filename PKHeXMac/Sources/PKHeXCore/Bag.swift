import CPKHeXNative

/// Kind of items a pouch holds. Raw values match PKHeX.Core's InventoryType enum.
public enum PouchType: Int32 {
    case none = 0
    case items, keyItems, tmhms, medicine, berries, balls, battleItems, mailItems
    case pcItems, freeSpace, zCrystals, candy, treasure, ingredients, megaStones

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .items: return "Items"
        case .keyItems: return "Key Items"
        case .tmhms: return "TMs/HMs"
        case .medicine: return "Medicine"
        case .berries: return "Berries"
        case .balls: return "Poké Balls"
        case .battleItems: return "Battle Items"
        case .mailItems: return "Mail"
        case .pcItems: return "PC Items"
        case .freeSpace: return "Free Space"
        case .zCrystals: return "Z-Crystals"
        case .candy: return "Candy"
        case .treasure: return "Treasure"
        case .ingredients: return "Ingredients"
        case .megaStones: return "Mega Stones"
        }
    }
}

/// One pouch (pocket) within a Bag, e.g. "Medicine" or "Poké Balls".
public struct Pouch {
    let bagHandle: Int64
    public let index: Int
    public let type: PouchType
    public let slotCount: Int

    /// True if this pouch has fewer slots than legal items (Gen 1-3's small free-form bags),
    /// meaning a slot must be freed/found rather than every item always having its own slot.
    public var isCramped: Bool {
        pkhex_bag_get_pouch_is_cramped(bagHandle, Int32(index)) == 1
    }

    /// Item IDs legal to carry in this pouch, for building an "add item" picker.
    public var legalItems: [Int] {
        let count = Int(pkhex_bag_get_pouch_legal_item_count(bagHandle, Int32(index)))
        return (0..<count).map { Int(pkhex_bag_get_pouch_legal_item(bagHandle, Int32(index), Int32($0))) }
    }

    public func itemIndex(_ slot: Int) -> Int {
        Int(pkhex_bag_get_item_index(bagHandle, Int32(index), Int32(slot)))
    }

    public func itemCount(_ slot: Int) -> Int {
        Int(pkhex_bag_get_item_count(bagHandle, Int32(index), Int32(slot)))
    }

    /// Display name for an item id from this pouch (from `itemIndex(_:)` or `legalItems`).
    /// Resolves through this bag's originating save's generation, since Gen 1-3 saves number
    /// items using their own legacy scheme rather than the shared/modern id space — use this
    /// instead of `PokemonNames.item(_:)` for any id that came from this bag.
    public func itemName(_ itemID: Int) -> String {
        let handle = bagHandle
        return readNativeString { pkhex_bag_get_item_name(handle, UInt16(itemID), $0, $1) }
    }

    /// Sets the item and quantity for a slot. Pass itemIndex 0 to clear the slot.
    public func setItem(_ slot: Int, itemIndex: Int, count: Int) {
        _ = pkhex_bag_set_item(bagHandle, Int32(index), Int32(slot), Int32(itemIndex), Int32(count))
    }

    /// Finds the first empty slot and assigns it to the given item/count. Returns the slot index
    /// used, or nil if the pouch is full.
    @discardableResult
    public func addItem(itemIndex: Int, count: Int) -> Int? {
        let slot = pkhex_bag_add_item(bagHandle, Int32(index), Int32(itemIndex), Int32(count))
        return slot >= 0 ? Int(slot) : nil
    }

    /// Removes the item at `slot` and shifts every following occupied slot down by one, so the
    /// pouch's occupied slots stay contiguous from index 0 with no gap left behind.
    public func removeItem(at slot: Int) {
        var write = slot
        for read in (slot + 1)..<slotCount {
            let index = itemIndex(read)
            if index == 0 { break }
            setItem(write, itemIndex: index, count: itemCount(read))
            write += 1
        }
        setItem(write, itemIndex: 0, count: 0)
    }

    /// Number of occupied slots, assuming occupied slots are packed contiguously from index 0.
    public var occupiedSlotCount: Int {
        var count = 0
        while count < slotCount, itemIndex(count) != 0 {
            count += 1
        }
        return count
    }
}

/// A snapshot of a save's inventory. Edits are made on this object and must be committed back
/// into the save with `commit(to:)`.
public final class Bag {
    let handle: Int64

    public let pouches: [Pouch]

    init(handle: Int64) {
        self.handle = handle
        let count = Int(pkhex_bag_get_pouch_count(handle))
        self.pouches = (0..<count).map { i in
            Pouch(
                bagHandle: handle,
                index: i,
                type: PouchType(rawValue: pkhex_bag_get_pouch_type(handle, Int32(i))) ?? .none,
                slotCount: Int(pkhex_bag_get_pouch_slot_count(handle, Int32(i)))
            )
        }
    }

    deinit {
        pkhex_bag_close(handle)
    }

    /// Writes this snapshot's item contents back into the save. Call `SaveFile.write()`
    /// afterward to persist the save to disk.
    public func commit(to saveFile: SaveFile) {
        _ = pkhex_bag_commit(handle, saveFile.handle)
    }
}
