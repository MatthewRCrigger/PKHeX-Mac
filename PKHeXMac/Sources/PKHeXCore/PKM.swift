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

    /// Number of selectable ability slots for this Pokemon's species/form: 0 (Gen 1-2, no
    /// abilities), 2 (Gen 3-4, Ability1/Ability2 only), or 3 (Gen 5+, adds a Hidden Ability slot).
    public var abilityCount: Int {
        Int(pkhex_pkm_get_ability_count(handle))
    }

    /// Ability ID for slot `index` (0=Ability1, 1=Ability2, 2=Hidden Ability), for building an
    /// ability picker's option list (`0..<abilityCount`).
    public func abilityID(at index: Int) -> UInt16 {
        pkhex_pkm_get_ability_at_index(handle, Int32(index))
    }

    /// Sets this Pokemon's ability to the one at the given slot index (0=Ability1, 1=Ability2,
    /// 2=Hidden Ability). Handles every generation's storage quirks correctly (e.g. Gen 3-5 need a
    /// PID re-roll to make the ability stick) — never write `ability` directly, there is no setter.
    public func setAbilityIndex(_ index: Int) {
        pkhex_pkm_set_ability_index(handle, Int32(index))
    }

    // MARK: - Met/Egg info

    /// Location ID this Pokemon was met at. Display name via `metLocationName`; candidate list via
    /// `metLocationOptions()`. The same numeric ID can mean a different place in a different game,
    /// so always resolve/pick through those rather than a static table.
    public var metLocation: UInt16 {
        get { pkhex_pkm_get_met_location(handle) }
        set { pkhex_pkm_set_met_location(handle, newValue) }
    }

    /// Location ID this Pokemon's egg was received/hatched at. Only meaningful when
    /// `supportsEggLocation` is true (Gen 4+). See `metLocation`'s remarks on resolving names.
    public var eggLocation: UInt16 {
        get { pkhex_pkm_get_egg_location(handle) }
        set { pkhex_pkm_set_egg_location(handle, newValue) }
    }

    /// Level this Pokemon was met/caught at.
    public var metLevel: UInt8 {
        get { pkhex_pkm_get_met_level(handle) }
        set { pkhex_pkm_set_met_level(handle, newValue) }
    }

    /// Whether this Pokemon was obtained via a scripted/fateful encounter (e.g. a Mystery Gift or
    /// static legendary encounter), rather than a normal wild/trade encounter.
    public var fatefulEncounter: Bool {
        get { pkhex_pkm_get_fateful_encounter(handle) != 0 }
        set { pkhex_pkm_set_fateful_encounter(handle, newValue ? 1 : 0) }
    }

    /// Whether this Pokemon's format tracks a Met Date at all (Gen 4+). Gate Met Date UI on this,
    /// not on `metDate == nil` — `nil` also legitimately means "present but unset/invalid".
    public var supportsMetDate: Bool { pkhex_pkm_get_supports_met_date(handle) != 0 }

    /// Whether this Pokemon's format tracks Egg Location/Date at all (Gen 4+). Gen 2-3 do have a
    /// working `isEgg` flag but no egg location/date storage — gate Egg Info location/date fields
    /// on this, separately from `supportsIsEgg`.
    public var supportsEggLocation: Bool { pkhex_pkm_get_supports_egg_location(handle) != 0 }

    /// Whether this Pokemon's format has any Is-Egg concept at all (Gen 2+; Gen 1 predates the Day
    /// Care/egg mechanic entirely). Gate the Is-Egg toggle's availability on this.
    public var supportsIsEgg: Bool { pkhex_pkm_get_supports_is_egg(handle) != 0 }

    /// Date this Pokemon was met, or `nil` if unsupported/unset/invalid for this format.
    public var metDate: DateComponents? {
        get {
            var year: Int32 = 0, month: Int32 = 0, day: Int32 = 0
            guard pkhex_pkm_get_met_date(handle, &year, &month, &day) != 0 else { return nil }
            return DateComponents(year: Int(year), month: Int(month), day: Int(day))
        }
        set {
            if let newValue, let year = newValue.year, let month = newValue.month, let day = newValue.day {
                pkhex_pkm_set_met_date(handle, Int32(year), Int32(month), Int32(day))
            } else {
                pkhex_pkm_set_met_date(handle, 0, 0, 0)
            }
        }
    }

    /// Date this Pokemon's egg was received/hatched, or `nil` if unsupported/unset/invalid. Only
    /// meaningful when `supportsEggLocation` is true.
    public var eggDate: DateComponents? {
        get {
            var year: Int32 = 0, month: Int32 = 0, day: Int32 = 0
            guard pkhex_pkm_get_egg_date(handle, &year, &month, &day) != 0 else { return nil }
            return DateComponents(year: Int(year), month: Int(month), day: Int(day))
        }
        set {
            if let newValue, let year = newValue.year, let month = newValue.month, let day = newValue.day {
                pkhex_pkm_set_egg_date(handle, Int32(year), Int32(month), Int32(day))
            } else {
                pkhex_pkm_set_egg_date(handle, 0, 0, 0)
            }
        }
    }

    /// Whether this Pokemon is currently an unhatched egg.
    public var isEgg: Bool {
        get { pkhex_pkm_get_is_egg(handle) != 0 }
        set { pkhex_pkm_set_is_egg(handle, newValue ? 1 : 0) }
    }

    /// Whether this Pokemon currently is an egg, or was originally received as one and has since
    /// hatched — i.e. it has legitimate egg history worth showing Egg Location/Date for, as opposed
    /// to a plain wild-caught Pokemon with no egg history.
    public var wasEgg: Bool { pkhex_pkm_get_was_egg(handle) != 0 }

    /// Candidate Met (or Egg, if `egg` is true) Location IDs and display names for this Pokemon's
    /// current version+context — mirrors PKHeX.WinForms' location combo contents, including
    /// per-version partitioning within a generation and any synthesized entries. Use to build a
    /// location picker.
    public func locationOptions(egg: Bool) -> [(id: UInt16, name: String)] {
        let count = Int(pkhex_pkm_get_location_count(handle, egg ? 1 : 0))
        return (0..<count).map { index in
            let id = pkhex_pkm_get_location_id_at_index(handle, egg ? 1 : 0, Int32(index))
            let name = readNativeString { pkhex_pkm_get_location_name(handle, id, egg ? 1 : 0, $0, $1) }
            return (id: id, name: name)
        }
    }

    /// Display name for this Pokemon's current Met Location, resolved through its version+context.
    public var metLocationName: String {
        readNativeString { pkhex_pkm_get_location_name(handle, metLocation, 0, $0, $1) }
    }

    /// Display name for this Pokemon's current Egg Location, resolved through its version+context.
    public var eggLocationName: String {
        readNativeString { pkhex_pkm_get_location_name(handle, eggLocation, 1, $0, $1) }
    }

    // MARK: - Original Trainer / Handling Trainer

    /// Name of this Pokemon's Original Trainer — may differ from the save's own trainer once
    /// traded. Not the same as `SaveFile.otName`, which is the player's own identity.
    public var originalTrainerName: String {
        get { readNativeString { pkhex_pkm_get_ot_name(handle, $0, $1) } }
        set { writeNativeString(newValue) { pkhex_pkm_set_ot_name(handle, $0, $1) } }
    }

    /// Maximum OT name length for this Pokemon's generation/language.
    public var maxOriginalTrainerNameLength: Int { Int(pkhex_pkm_get_max_ot_name_length(handle)) }

    /// 0 = male, 1 = female.
    public var originalTrainerGender: UInt8 {
        get { pkhex_pkm_get_ot_gender(handle) }
        set { pkhex_pkm_set_ot_gender(handle, newValue) }
    }

    public var originalTrainerFriendship: UInt8 {
        get { pkhex_pkm_get_ot_friendship(handle) }
        set { pkhex_pkm_set_ot_friendship(handle, newValue) }
    }

    public var tid16: UInt16 {
        get { pkhex_pkm_get_tid16(handle) }
        set { pkhex_pkm_set_tid16(handle, newValue) }
    }

    public var sid16: UInt16 {
        get { pkhex_pkm_get_sid16(handle) }
        set { pkhex_pkm_set_sid16(handle, newValue) }
    }

    /// Resets OT name/gender/TID/SID/language to the given save's own trainer identity — undoes
    /// trade history stamped into the OT fields. Does not touch Handling Trainer fields or
    /// memories; pair with `currentHandler = 0` and `clearMemories()` for a full "make this
    /// Pokemon look untraded" reset.
    public func resetOriginalTrainerToSaveTrainer(_ saveFile: SaveFile) {
        pkhex_pkm_reset_ot_to_save_trainer(handle, saveFile.handle)
    }

    /// Whether this Pokemon's format has any Handling Trainer concept at all (Gen 6+). Gate
    /// Handling Trainer UI on this.
    public var supportsHandlingTrainer: Bool { pkhex_pkm_get_supports_handling_trainer(handle) != 0 }

    /// Whether this Pokemon currently has Handling Trainer data set at all (i.e. has been traded
    /// at least once) — gate whether to show the HT UI at all, distinct from `currentHandler`
    /// (who holds it right now).
    public var hasHandlingTrainer: Bool { pkhex_pkm_get_has_handling_trainer(handle) != 0 }

    public var handlingTrainerName: String {
        get { readNativeString { pkhex_pkm_get_ht_name(handle, $0, $1) } }
        set { writeNativeString(newValue) { pkhex_pkm_set_ht_name(handle, $0, $1) } }
    }

    /// 0 = male, 1 = female.
    public var handlingTrainerGender: UInt8 {
        get { pkhex_pkm_get_ht_gender(handle) }
        set { pkhex_pkm_set_ht_gender(handle, newValue) }
    }

    public var handlingTrainerFriendship: UInt8 {
        get { pkhex_pkm_get_ht_friendship(handle) }
        set { pkhex_pkm_set_ht_friendship(handle, newValue) }
    }

    /// 0 = Original Trainer currently possesses this Pokemon, 1 = Handling Trainer does (traded).
    public var currentHandler: UInt8 {
        get { pkhex_pkm_get_current_handler(handle) }
        set { pkhex_pkm_set_current_handler(handle, newValue) }
    }

    // MARK: - Memories

    /// Whether this Pokemon's format tracks Original Trainer memories at all. Gen 6-9 track them
    /// except Let's Go Pikachu/Eevee, which dropped the Amie/memory mechanic entirely.
    public var supportsOriginalTrainerMemory: Bool { pkhex_pkm_get_supports_ot_memory(handle) != 0 }

    /// Whether this Pokemon's format tracks Handling Trainer memories.
    public var supportsHandlingTrainerMemory: Bool { pkhex_pkm_get_supports_ht_memory(handle) != 0 }

    public var originalTrainerMemory: UInt8 {
        get { pkhex_pkm_get_ot_memory(handle) }
        set { pkhex_pkm_set_ot_memory(handle, newValue) }
    }

    public var originalTrainerMemoryIntensity: UInt8 {
        get { pkhex_pkm_get_ot_memory_intensity(handle) }
        set { pkhex_pkm_set_ot_memory_intensity(handle, newValue) }
    }

    public var originalTrainerMemoryFeeling: UInt8 {
        get { pkhex_pkm_get_ot_memory_feeling(handle) }
        set { pkhex_pkm_set_ot_memory_feeling(handle, newValue) }
    }

    public var originalTrainerMemoryVariable: UInt16 {
        get { pkhex_pkm_get_ot_memory_variable(handle) }
        set { pkhex_pkm_set_ot_memory_variable(handle, newValue) }
    }

    public var handlingTrainerMemory: UInt8 {
        get { pkhex_pkm_get_ht_memory(handle) }
        set { pkhex_pkm_set_ht_memory(handle, newValue) }
    }

    public var handlingTrainerMemoryIntensity: UInt8 {
        get { pkhex_pkm_get_ht_memory_intensity(handle) }
        set { pkhex_pkm_set_ht_memory_intensity(handle, newValue) }
    }

    public var handlingTrainerMemoryFeeling: UInt8 {
        get { pkhex_pkm_get_ht_memory_feeling(handle) }
        set { pkhex_pkm_set_ht_memory_feeling(handle, newValue) }
    }

    public var handlingTrainerMemoryVariable: UInt16 {
        get { pkhex_pkm_get_ht_memory_variable(handle) }
        set { pkhex_pkm_set_ht_memory_variable(handle, newValue) }
    }

    /// Zeroes OT + HT memory fields.
    public func clearMemories() {
        pkhex_pkm_clear_memories(handle)
    }

    /// Valid Memory IDs for this Pokemon's context (0 = "None" always included), for building a
    /// memory picker.
    public var memoryIDOptions: [UInt8] {
        let count = Int(pkhex_pkm_get_memory_id_count(handle))
        return (0..<count).map { pkhex_pkm_get_memory_id_at_index(handle, Int32($0)) }
    }

    /// Raw sentence template for a memory id, e.g. "{0} met {1} {2}. {4} that {3}." — for a memory
    /// picker's option label.
    public func memoryLine(_ memoryID: UInt8) -> String {
        readNativeString { pkhex_memory_get_line(memoryID, $0, $1) }
    }

    /// What kind of value a memory's "variable" (TextVar) field means: 0=None, 1=GeneralLocation,
    /// 2=SpecificLocation, 3=Species, 4=Move, 5=Item. Decides which picker to show for the
    /// variable field.
    public func memoryVariableArgType(_ memoryID: UInt8) -> UInt8 {
        pkhex_memory_get_variable_arg_type(handle, memoryID)
    }

    /// Display name for a memory's variable value (e.g. "Route 5" instead of a bare numeric
    /// TextVar), resolved per `memoryVariableArgType`.
    public func memoryVariableName(_ memoryID: UInt8, variable: UInt16) -> String {
        readNativeString { pkhex_memory_get_variable_name(handle, memoryID, variable, $0, $1) }
    }

    /// Lowest legal Intensity value for a given memory id.
    public func memoryMinimumIntensity(_ memoryID: UInt8) -> UInt8 {
        pkhex_memory_get_minimum_intensity(handle, memoryID)
    }

    /// Sets a known-legal "arrived via Link Trade" Handling Trainer memory — the same values
    /// PKHeX.WinForms suggests when a trade is detected.
    public func setTradeMemoryHT() {
        pkhex_pkm_set_trade_memory_ht(handle)
    }

    // MARK: - Legality (structured)

    /// One granular legality check result, for a "here's what's wrong" UI beyond the flat text
    /// report (`legalityReasons`).
    public struct LegalityResult {
        public let severity: Int8
        public let identifier: UInt8
        public let message: String

        /// True if this result represents an actual problem (Invalid or Fishy), not a routine
        /// "this passed" entry.
        public var isIssue: Bool { severity <= 0 }
    }

    /// Every individual legality check result for this Pokemon, both passing and failing — filter
    /// on `isIssue` to show only problems. Building block for a granular legality UI, grouped by
    /// `identifier` (matches PKHeX.Core's `CheckIdentifier` ordinal).
    public var legalityResults: [LegalityResult] {
        let count = Int(pkhex_pkm_get_legality_result_count(handle))
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let severity = pkhex_pkm_get_legality_result_severity(handle, Int32(index))
            let identifier = pkhex_pkm_get_legality_result_identifier(handle, Int32(index))
            let message = readNativeString { pkhex_pkm_get_legality_result_message(handle, Int32(index), $0, $1) }
            return LegalityResult(severity: severity, identifier: identifier, message: message)
        }
    }

    /// Applies a curated, mechanically-safe quick-fix for the legality result at `index`, if one
    /// is available for its category (Trainer/Memory/Handler/Ball). There is no general "make
    /// legal" engine in PKHeX.Core to wrap — this only covers common, unambiguous repairs. Returns
    /// true if a fix was applied.
    @discardableResult
    public func applyLegalityFix(at index: Int, saveFile: SaveFile) -> Bool {
        pkhex_pkm_apply_legality_fix(handle, saveFile.handle, Int32(index)) == 1
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

    /// Type ID (see `PokemonNames.type`) of the given move ID, resolved for this Pokemon's game
    /// context (a handful of moves' types differ across generations). Pass move ID 0 for "—".
    public func moveType(_ move: UInt16) -> UInt8 {
        move == 0 ? 0 : pkhex_pkm_get_move_type(handle, move)
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

    /// Base max PP (0 PP Ups) for an arbitrary move ID — what it would show if newly selected into
    /// a slot (selecting a move always resets PP Ups to 0). Use `movePPMax(_:)` instead for a move
    /// already equipped in a slot, which accounts for any PP Ups applied.
    public func moveBasePP(_ move: UInt16) -> Int32 {
        pkhex_pkm_get_move_base_pp(handle, move)
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

    /// Short flavor-text description of an ability, e.g. "Powers up moves of the same type."
    /// Empty if unknown/not yet catalogued (a handful of very new abilities have no description
    /// available in the source data set — see Scripts/generate_ability_descriptions.py).
    public static func abilityDescription(_ id: UInt16) -> String {
        readNativeString { pkhex_ability_get_description(id, $0, $1) }
    }

    /// Display name for a Ball ID (see PKHeX.Core's Ball enum), e.g. "Poké Ball".
    public static func ball(_ id: UInt8) -> String {
        readNativeString { pkhex_ball_get_name(id, $0, $1) }
    }

    /// Programmatic name of a `PKM.LegalityResult.identifier` value (e.g. "Trainer", "Memory",
    /// "Ball", "Handler") — matches PKHeX.Core's `CheckIdentifier` enum member name exactly, not a
    /// display string. Use to switch on category by name rather than hardcoding ordinal numbers.
    public static func checkIdentifier(_ id: UInt8) -> String {
        readNativeString { pkhex_check_identifier_get_name(id, $0, $1) }
    }
}
