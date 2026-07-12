import CPKHeXNative
import Foundation

/// A stat index into the IV/EV accessors: HP, Attack, Defense, Sp. Atk, Sp. Def, Speed.
public enum Stat: Int32, CaseIterable {
    case hp = 0, attack, defense, specialAttack, specialDefense, speed
}

/// Normalized field/battle status condition for a party Pokemon. Values match PKHeX.Native's
/// pkhex_pkm_get_status_type exactly, which normalizes both the Gen1-4 bitflag layout and the
/// Gen5+ plain-enum layout of the underlying Status_Condition field into one shared enum. Only
/// meaningful for Pokemon with `partyStatsPresent == true` — box-stored Pokemon aren't "in the
/// field" and have no meaningful status.
public enum StatusCondition: UInt8, CaseIterable {
    case none = 0
    case paralysis
    case sleep
    case freeze
    case burn
    case poison

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .paralysis: return "Paralyzed"
        case .sleep: return "Asleep"
        case .freeze: return "Frozen"
        case .burn: return "Burned"
        case .poison: return "Poisoned"
        }
    }
}

/// Wraps a single Pokemon (box slot or party member) handle from PKHeX.Native.
public final class PKM {
    let handle: Int64

    init(handle: Int64) {
        self.handle = handle
    }

    deinit {
        pkhex_pkm_close(handle)
    }

    public var species: UInt16 {
        get { pkhex_pkm_get_species(handle) }
        set { pkhex_pkm_set_species(handle, newValue) }
    }

    /// Generation this entity's format belongs to (1-9).
    public var format: UInt8 { pkhex_pkm_get_format(handle) }

    public var level: UInt8 {
        get { pkhex_pkm_get_level(handle) }
        set { pkhex_pkm_set_level(handle, newValue) }
    }

    public var nature: UInt8 {
        get { pkhex_pkm_get_nature(handle) }
        set { pkhex_pkm_set_nature(handle, newValue) }
    }

    /// 0 = male, 1 = female, 2 = genderless.
    public var gender: UInt8 {
        get { pkhex_pkm_get_gender(handle) }
        set { pkhex_pkm_set_gender(handle, newValue) }
    }

    /// Raw Ball value (see PKHeX.Core's Ball enum: 0 = None, 4 = Poké Ball, etc).
    /// Only meaningful when `supportsBall` is true — Gen 1/2 entities have no ball concept and
    /// always report 0 here regardless of what's set.
    public var ball: UInt8 {
        get { pkhex_pkm_get_ball(handle) }
        set { pkhex_pkm_set_ball(handle, newValue) }
    }

    /// Whether this Pokemon's format actually tracks which Ball it was caught in. Gen 1/2 (format
    /// 1/2) predate the Ball byte in PKHeX.Core's data model, so `ball` is a permanent no-op there
    /// — gate any ball UI on this rather than on `ball == 0`, since 0 ("None") is also a valid,
    /// legitimate reading on Gen 3+ entities.
    public var supportsBall: Bool { format >= 3 }

    public var isShiny: Bool {
        pkhex_pkm_get_is_shiny(handle) == 1
    }

    /// True if this Pokemon has computed party stats (i.e. it came from a party slot, not a box
    /// slot). Box-stored Pokemon have no "in the field" state — gate status-condition UI on this.
    public var partyStatsPresent: Bool {
        pkhex_pkm_get_party_stats_present(handle) == 1
    }

    /// Field/battle status condition (burned, paralyzed, asleep, etc). Only meaningful when
    /// `partyStatsPresent` is true.
    public var status: StatusCondition {
        get { StatusCondition(rawValue: pkhex_pkm_get_status_type(handle)) ?? .none }
        set { pkhex_pkm_set_status_type(handle, newValue.rawValue) }
    }

    public var heldItem: UInt16 {
        get { pkhex_pkm_get_held_item(handle) }
        set { pkhex_pkm_set_held_item(handle, newValue) }
    }

    /// Current ability ID (already resolved for this Pokemon's ability slot).
    public var ability: UInt16 {
        pkhex_pkm_get_ability(handle)
    }

    /// Primary and secondary type IDs; `type2 == type1` for single-type species.
    public var type1: UInt8 { pkhex_pkm_get_type1(handle) }
    public var type2: UInt8 { pkhex_pkm_get_type2(handle) }

    /// This Pokemon's type IDs, deduplicated (one entry for single-type species).
    public var types: [UInt8] {
        type1 == type2 ? [type1] : [type1, type2]
    }

    /// Display name for this Pokemon's current held item, e.g. "Leftovers". Empty if none held.
    /// Resolved through this Pokemon's own generation, correct for Gen 1-3 (which number items
    /// differently than the shared/modern id space `PokemonNames.item(_:)` assumes).
    public var heldItemName: String {
        guard heldItem != 0 else { return "" }
        return readNativeString { pkhex_pkm_get_held_item_name(handle, $0, $1) }
    }

    /// Display name for an arbitrary item id, resolved through this Pokemon's own generation (see
    /// `heldItemName`'s remarks) — for listing held-item picker candidates
    /// (`1...maxItemID`), not just the currently-held item.
    public func itemName(_ id: UInt16) -> String {
        readNativeString { pkhex_pkm_get_item_name(handle, id, $0, $1) }
    }

    /// Display name for this Pokemon's current ability, e.g. "Intimidate".
    public var abilityName: String {
        PokemonNames.ability(ability)
    }

    public func move(_ index: Int) -> UInt16 {
        pkhex_pkm_get_move(handle, Int32(index))
    }

    public func setMove(_ index: Int, to move: UInt16) {
        pkhex_pkm_set_move(handle, Int32(index), move)
    }

    public var moves: [UInt16] {
        (0..<4).map { move($0) }
    }

    /// Move IDs this Pokemon can currently legally learn (level-up, egg, TM/tutor, and moves from
    /// its recorded encounter/relearn set), for building a move picker. Does not include move ID 0
    /// ("None"); add that yourself as a placeholder for clearing a slot. Falls back to every move
    /// up to `maxMoveID` if legality analysis found no legal moves (e.g. malformed data).
    public var legalMoves: [UInt16] {
        let count = Int(pkhex_pkm_get_legal_move_count(handle))
        guard count > 0 else {
            return maxMoveID > 0 ? Array(1...maxMoveID) : []
        }
        return (0..<count).map { pkhex_pkm_get_legal_move(handle, Int32($0)) }
    }

    /// Highest move ID valid for this Pokemon's format.
    public var maxMoveID: UInt16 {
        pkhex_pkm_get_max_move_id(handle)
    }

    /// Highest item ID valid for this Pokemon's format, for building a held-item picker
    /// (e.g. `1...maxItemID`, same shape as the species/move pickers).
    public var maxItemID: UInt16 {
        pkhex_pkm_get_max_item_id(handle)
    }

    public func iv(_ stat: Stat) -> Int32 {
        pkhex_pkm_get_iv(handle, stat.rawValue)
    }

    public func setIV(_ stat: Stat, to value: Int32) {
        pkhex_pkm_set_iv(handle, stat.rawValue, value)
    }

    public func ev(_ stat: Stat) -> Int32 {
        pkhex_pkm_get_ev(handle, stat.rawValue)
    }

    public func setEV(_ stat: Stat, to value: Int32) {
        pkhex_pkm_set_ev(handle, stat.rawValue, value)
    }

    public var nickname: String {
        get { readNativeString { pkhex_pkm_get_nickname(handle, $0, $1) } }
        set { writeNativeString(newValue) { pkhex_pkm_set_nickname(handle, $0, $1) } }
    }

    /// Maximum nickname length for this Pokemon's generation/language.
    public var maxNicknameLength: Int { Int(pkhex_pkm_get_max_nickname_length(handle)) }

    /// Base file name (without extension) for this Pokemon's sprite, e.g. "b_25-1s".
    /// Matches image asset names generated by Scripts/generate_sprite_assets.py.
    public var spriteFileName: String {
        readNativeString { pkhex_pkm_get_sprite_file_name(handle, $0, $1) }
    }

    /// Base file name (without extension) for this Pokemon's artwork, e.g. "a_1025-1s". A newer,
    /// higher-coverage icon set than `spriteFileName` (species up to #1025 vs ~#905) — see
    /// Scripts/generate_artwork_assets.py. Not every form/shiny combination is guaranteed to exist
    /// in the shipped asset catalog; use `ArtworkImage` (SwiftUI view) rather than loading this
    /// name directly, since it applies the documented fallback chain (strip shiny, then form, then
    /// fall back to the older sprite set) for names missing from the catalog.
    public var artworkFileName: String {
        readNativeString { pkhex_pkm_get_artwork_file_name(handle, $0, $1) }
    }

    public var isLegal: Bool {
        pkhex_pkm_is_legal(handle) == 1
    }

    public func legalityReport(verbose: Bool = false) -> String {
        readNativeString { pkhex_pkm_get_legality_report(handle, $0, $1, verbose ? 1 : 0) }
    }

    /// Human-readable legality reasons, one per line; empty if legal. Use `.first` for a banner's
    /// "first reason" summary.
    public var legalityReasons: [String] {
        let report = readNativeString { pkhex_pkm_get_legality_lines(handle, $0, $1) }
        return report.isEmpty ? [] : report.split(separator: "\n").map(String.init)
    }

    /// Display name for this Pokemon's current species, e.g. "Totodile".
    public var speciesName: String {
        PokemonNames.species(species)
    }

    /// Display name for this Pokemon's current nature, e.g. "Adamant".
    public var natureName: String {
        PokemonNames.nature(nature)
    }

    /// Display name for this Pokemon's current ball, e.g. "Poké Ball". Only meaningful when
    /// `supportsBall` is true.
    public var ballName: String {
        PokemonNames.ball(ball)
    }

    /// Current PP remaining in the given move slot (0-3).
    public func movePP(_ index: Int) -> Int32 {
        pkhex_pkm_get_move_pp(handle, Int32(index))
    }

    /// Maximum PP (accounting for PP Ups) for the move currently in the given slot (0-3).
    public func movePPMax(_ index: Int) -> Int32 {
        pkhex_pkm_get_move_pp_max(handle, Int32(index))
    }
}

/// Display-name lookups for species/move/nature/item IDs, backed by PKHeX.Core's current-language
/// string tables. Independent of any PKM instance.
public enum PokemonNames {
    public static func species(_ id: UInt16) -> String {
        readNativeString { pkhex_species_get_name(id, $0, $1) }
    }

    public static func move(_ id: UInt16) -> String {
        readNativeString { pkhex_move_get_name(id, $0, $1) }
    }

    public static func nature(_ id: UInt8) -> String {
        readNativeString { pkhex_nature_get_name(id, $0, $1) }
    }

    public static func item(_ id: UInt16) -> String {
        readNativeString { pkhex_item_get_name(id, $0, $1) }
    }

    /// Display name for a type ID, e.g. "Fire", "Water".
    public static func type(_ id: UInt8) -> String {
        readNativeString { pkhex_type_get_name(id, $0, $1) }
    }

    public static func ability(_ id: UInt16) -> String {
        readNativeString { pkhex_ability_get_name(id, $0, $1) }
    }

    /// Display name for a Ball ID (see PKHeX.Core's Ball enum), e.g. "Poké Ball".
    public static func ball(_ id: UInt8) -> String {
        readNativeString { pkhex_ball_get_name(id, $0, $1) }
    }
}
