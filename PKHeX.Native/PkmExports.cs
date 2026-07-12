using System;
using System.Runtime.InteropServices;
using PKHeX.Core;
using PKHeX.Native.Sprites;

namespace PKHeX.Native;

public static class PkmExports
{
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_close")]
    public static void PkmClose(long handle) => HandleTable.Remove(handle);

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_species")]
    public static ushort PkmGetSpecies(long handle) => HandleTable.Get<PKM>(handle)?.Species ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_species")]
    public static void PkmSetSpecies(long handle, ushort species)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.Species = species;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_format")]
    public static byte PkmGetFormat(long handle) => HandleTable.Get<PKM>(handle)?.Format ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_level")]
    public static byte PkmGetLevel(long handle) => HandleTable.Get<PKM>(handle)?.CurrentLevel ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_level")]
    public static void PkmSetLevel(long handle, byte level)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.CurrentLevel = level;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_nature")]
    public static byte PkmGetNature(long handle) => (byte)(HandleTable.Get<PKM>(handle)?.Nature ?? 0);

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_nature")]
    public static void PkmSetNature(long handle, byte nature)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.Nature = (Nature)nature;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ball")]
    public static byte PkmGetBall(long handle) => HandleTable.Get<PKM>(handle)?.Ball ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ball")]
    public static void PkmSetBall(long handle, byte ball)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.Ball = ball;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_gender")]
    public static byte PkmGetGender(long handle) => HandleTable.Get<PKM>(handle)?.Gender ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_gender")]
    public static void PkmSetGender(long handle, byte gender)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.Gender = gender;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_is_shiny")]
    public static byte PkmGetIsShiny(long handle) => (byte)(HandleTable.Get<PKM>(handle)?.IsShiny == true ? 1 : 0);

    /// <summary>
    /// True if this PKM has computed party stats (i.e. it was read from a party slot, not a box
    /// slot). Box-stored Pokemon have no meaningful "in the field" state, so status condition
    /// should be treated as not-applicable/hidden when this is false, even if the raw status byte
    /// happens to be nonzero.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_party_stats_present")]
    public static byte PkmGetPartyStatsPresent(long handle) => (byte)(HandleTable.Get<PKM>(handle)?.PartyStatsPresent == true ? 1 : 0);

    /// <summary>
    /// Normalized status condition (0=None, 1=Paralysis, 2=Sleep, 3=Freeze, 4=Burn, 5=Poison),
    /// matching PKHeX.Core's Gen5+ StatusType enum regardless of which generation this PKM
    /// actually is. Uses PKM.GetStatusType(), which decodes the raw Status_Condition int (whose
    /// bit layout differs between Gen1-4's StatusCondition bitflags and Gen5+'s plain StatusType)
    /// the same way for every generation.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_status_type")]
    public static byte PkmGetStatusType(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        return (byte)pk.GetStatusType();
    }

    /// <summary>
    /// Sets the status condition from a normalized StatusType value (see pkhex_pkm_get_status_type).
    /// Writes a raw Status_Condition value chosen so that PKM.GetStatusType() decodes back to the
    /// same StatusType for BOTH the Gen1-4 bitflag layout and the Gen5+ plain-enum layout (that
    /// method doesn't branch on generation, so one set of raw values is correct everywhere):
    /// None=0, Sleep=2 (any 1-7 value reads as asleep), Paralysis=1&lt;&lt;6, Burn=1&lt;&lt;4,
    /// Poison=1&lt;&lt;3, Freeze=1&lt;&lt;5. A naive "raw = (int)StatusType" would be wrong for
    /// Gen1-4 since e.g. StatusType.Poison=5 falls inside the 1-7 "asleep" range there.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_status_type")]
    public static void PkmSetStatusType(long handle, byte statusType)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        pk.Status_Condition = (StatusType)statusType switch
        {
            StatusType.None => 0,
            StatusType.Sleep => (int)StatusCondition.Sleep2,
            StatusType.Paralysis => (int)StatusCondition.Paralysis,
            StatusType.Burn => (int)StatusCondition.Burn,
            StatusType.Freeze => (int)StatusCondition.Freeze,
            StatusType.Poison => (int)StatusCondition.Poison,
            _ => 0,
        };
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_held_item")]
    public static ushort PkmGetHeldItem(long handle) => (ushort)(HandleTable.Get<PKM>(handle)?.HeldItem ?? 0);

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_held_item")]
    public static void PkmSetHeldItem(long handle, ushort item)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.HeldItem = item;
    }

    /// <summary>
    /// Writes the display name of this PKM's held item into <paramref name="outBuffer"/>, resolved
    /// through its own generation context. Use this instead of pkhex_item_get_name for held items —
    /// Gen 1-3 entities store the held item id using their own legacy numbering, not the shared/
    /// modern id space pkhex_item_get_name assumes.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_held_item_name")]
    public static unsafe int PkmGetHeldItemName(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk || pk.HeldItem == 0)
            return 0;
        return WriteItemNameForContext(pk, (ushort)pk.HeldItem, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the display name of an arbitrary item id, resolved through this PKM's own generation
    /// context (see pkhex_pkm_get_held_item_name's remarks) — for building a held-item picker that
    /// lists candidate items (1...pkhex_pkm_get_max_item_id) rather than just the currently-held one.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_item_name")]
    public static unsafe int PkmGetItemName(long handle, ushort item, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return WriteItemNameForContext(pk, item, outBuffer, outBufferLength);
    }

    private static unsafe int WriteItemNameForContext(PKM pk, ushort item, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.GetItemStrings(pk.Context, pk.Version);
        var name = item < list.Length ? list[item] : "";
        if (outBuffer is null || outBufferLength < name.Length)
            return name.Length;
        name.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return name.Length;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ability")]
    public static ushort PkmGetAbility(long handle) => (ushort)(HandleTable.Get<PKM>(handle)?.Ability ?? 0);

    /// <summary>
    /// Number of selectable ability slots for this PKM's species/form: 0 (Gen 1-2, no abilities),
    /// 2 (Gen 3-4, Ability1/Ability2 only), or 3 (Gen 5+, adds a Hidden Ability slot).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ability_count")]
    public static int PkmGetAbilityCount(long handle) => HandleTable.Get<PKM>(handle)?.PersonalInfo.AbilityCount ?? 0;

    /// <summary>
    /// Ability ID for slot <paramref name="index"/> (0=Ability1, 1=Ability2, 2=Hidden Ability) of
    /// this PKM's species/form personal info, for building an ability picker's option list
    /// alongside pkhex_pkm_get_ability_count.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ability_at_index")]
    public static ushort PkmGetAbilityAtIndex(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        var pi = pk.PersonalInfo;
        if ((uint)index >= pi.AbilityCount)
            return 0;
        return (ushort)pi.GetAbilityAtIndex(index);
    }

    /// <summary>
    /// Sets this PKM's ability to the one at the given slot index (0=Ability1, 1=Ability2,
    /// 2=Hidden Ability), via PKHeX.Core's PKM.SetAbilityIndex — this correctly handles every
    /// generation's storage quirks (Gen 3's PID-bit-derived ability, Gen 4/5's PID-derived ability
    /// slot requiring a PID re-roll, Gen 6+'s independently stored Ability/AbilityNumber bytes)
    /// rather than writing PKM.Ability directly, which is a silent no-op on Gen 3 and leaves a
    /// mismatched AbilityNumber on Gen 4/5.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ability_index")]
    public static void PkmSetAbilityIndex(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        if ((uint)index >= pk.PersonalInfo.AbilityCount)
            return;
        pk.SetAbilityIndex(index);
    }

    /// <summary>Primary type ID (see pkhex_type_get_name).</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_type1")]
    public static byte PkmGetType1(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        return NormalizeType(pk.PersonalInfo.Type1, pk.Format);
    }

    /// <summary>Secondary type ID, equal to Type1 if the species has only one type.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_type2")]
    public static byte PkmGetType2(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        return NormalizeType(pk.PersonalInfo.Type2, pk.Format);
    }

    /// <summary>
    /// Generations 1-2 store Type1/Type2 using an internal byte layout that doesn't match the
    /// modern MoveType numbering exposed via pkhex_type_get_name/GameInfo.Strings.types (e.g. Ghost
    /// is legacy byte 8 but modern id 7; Steel/Dark, added mid-Gen2, sit at legacy 9/27 rather than
    /// their modern 8/16). Remap legacy bytes to modern ids so type badges/lookups are correct for
    /// Gen 1-2 saves. Verified against known species (Gastly=Ghost/Poison, Steelix=Steel/Ground,
    /// Skarmory=Steel/Flying, Tyranitar=Rock/Dark, etc).
    /// </summary>
    private static byte NormalizeType(byte value, byte format)
    {
        if (format > 2)
            return value;
        if (value <= 5) return value;       // Normal..Rock unchanged
        if (value <= 9) return (byte)(value - 1); // Bug(7)->6, Ghost(8)->7, Steel(9)->8
        return (byte)(value - 11);          // Fire(20)->9 .. Dark(27)->16
    }

    // Moves: index 0-3.
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_move")]
    public static ushort PkmGetMove(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        return index switch { 0 => pk.Move1, 1 => pk.Move2, 2 => pk.Move3, 3 => pk.Move4, _ => 0 };
    }

    /// <summary>
    /// Sets the move in the given slot (0-3) and resets its PP to full (PP Ups cleared), matching
    /// how PKHeX's own editors behave when a move is changed. Pass move 0 to clear the slot.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_move")]
    public static void PkmSetMove(long handle, int index, ushort move)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        var pp = move == 0 ? 0 : pk.GetMovePP(move, 0);
        switch (index)
        {
            case 0: pk.Move1 = move; pk.Move1_PPUps = 0; pk.Move1_PP = pp; break;
            case 1: pk.Move2 = move; pk.Move2_PPUps = 0; pk.Move2_PP = pp; break;
            case 2: pk.Move3 = move; pk.Move3_PPUps = 0; pk.Move3_PP = pp; break;
            case 3: pk.Move4 = move; pk.Move4_PPUps = 0; pk.Move4_PP = pp; break;
        }
    }

    /// <summary>
    /// Type ID (see pkhex_type_get_name) of the given move ID, resolved for this PKM's game
    /// context — a small number of moves' types differ across generations (e.g. Charm, Moonlight),
    /// so the lookup is context-dependent rather than a plain move -> type table.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_move_type")]
    public static byte PkmGetMoveType(long handle, ushort move)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        return MoveInfo.GetType(move, pk.Context);
    }

    // IVs/EVs: stat index 0=HP,1=ATK,2=DEF,3=SPA,4=SPD,5=SPE (matches display convention).
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_iv")]
    public static int PkmGetIV(long handle, int stat)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return stat switch { 0 => pk.IV_HP, 1 => pk.IV_ATK, 2 => pk.IV_DEF, 3 => pk.IV_SPA, 4 => pk.IV_SPD, 5 => pk.IV_SPE, _ => -1 };
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_iv")]
    public static void PkmSetIV(long handle, int stat, int value)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        switch (stat)
        {
            case 0: pk.IV_HP = value; break;
            case 1: pk.IV_ATK = value; break;
            case 2: pk.IV_DEF = value; break;
            case 3: pk.IV_SPA = value; break;
            case 4: pk.IV_SPD = value; break;
            case 5: pk.IV_SPE = value; break;
        }
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ev")]
    public static int PkmGetEV(long handle, int stat)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return stat switch { 0 => pk.EV_HP, 1 => pk.EV_ATK, 2 => pk.EV_DEF, 3 => pk.EV_SPA, 4 => pk.EV_SPD, 5 => pk.EV_SPE, _ => -1 };
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ev")]
    public static void PkmSetEV(long handle, int stat, int value)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        switch (stat)
        {
            case 0: pk.EV_HP = value; break;
            case 1: pk.EV_ATK = value; break;
            case 2: pk.EV_DEF = value; break;
            case 3: pk.EV_SPA = value; break;
            case 4: pk.EV_SPD = value; break;
            case 5: pk.EV_SPE = value; break;
        }
    }

    /// <summary>
    /// Writes the nickname as UTF-16 code units into <paramref name="outBuffer"/> (length in chars).
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_nickname")]
    public static unsafe int PkmGetNickname(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        var name = pk.Nickname;
        if (outBuffer is null || outBufferLength < name.Length)
            return name.Length;
        name.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return name.Length;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_nickname")]
    public static unsafe void PkmSetNickname(long handle, char* name, int length)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        pk.Nickname = new string(new ReadOnlySpan<char>(name, length));
    }

    /// <summary>
    /// Maximum nickname length (in characters) for this PKM's generation/language.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_max_nickname_length")]
    public static int PkmGetMaxNicknameLength(long handle) => HandleTable.Get<PKM>(handle)?.MaxStringLengthNickname ?? 0;

    /// <summary>
    /// Writes the base sprite file name (without extension, e.g. "b_25-1s") for this PKM's
    /// current species/form/gender/shininess into <paramref name="outBuffer"/> (length in chars).
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_sprite_file_name")]
    public static unsafe int PkmGetSpriteFileName(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;

        var formarg = pk is IFormArgument f ? f.FormArgument : 0;
        var name = SpriteFileName.GetSpriteFileName(pk.Species, pk.Form, pk.Gender, formarg, pk.Context, pk.IsShiny);
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the base artwork file name (without extension, e.g. "a_1025", "a_25-1") for this
    /// PKM's current species/form/gender/shininess into <paramref name="outBuffer"/> (length in
    /// chars). This is a separate, newer icon set (see ArtworkFileName.cs) covering species up
    /// through National Dex #1025 — prefer it over pkhex_pkm_get_sprite_file_name's set, which
    /// stops around #905. The exact generated name is not guaranteed to exist in the shipped asset
    /// catalog for every form/shiny combination; callers should fall back to a form/shiny-stripped
    /// variant (and ultimately pkhex_pkm_get_sprite_file_name) if the named asset is missing.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_artwork_file_name")]
    public static unsafe int PkmGetArtworkFileName(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;

        var formarg = pk is IFormArgument f ? f.FormArgument : 0;
        var name = ArtworkFileName.GetArtworkFileName(pk.Species, pk.Form, pk.Gender, formarg, pk.Context, pk.IsShiny);
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the current (English) display name of a species ID into <paramref name="outBuffer"/>.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_species_get_name")]
    public static unsafe int SpeciesGetName(ushort species, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.specieslist;
        var name = species < list.Length ? list[species] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the current (English) display name of a move ID into <paramref name="outBuffer"/>.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_move_get_name")]
    public static unsafe int MoveGetName(ushort move, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.movelist;
        var name = move < list.Length ? list[move] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the current (English) display name of a Nature value into <paramref name="outBuffer"/>.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_nature_get_name")]
    public static unsafe int NatureGetName(byte nature, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.natures;
        var name = nature < list.Length ? list[nature] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the current (English) display name of a Move-type (0-18, matches PKHeX.Core's
    /// MoveType enum) into <paramref name="outBuffer"/>, e.g. "Fire", "Water".
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_type_get_name")]
    public static unsafe int TypeGetName(byte type, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.types;
        var name = type < list.Length ? list[type] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the current (English) display name of an Ability ID into <paramref name="outBuffer"/>.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_ability_get_name")]
    public static unsafe int AbilityGetName(ushort ability, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.abilitylist;
        var name = ability < list.Length ? list[ability] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the short flavor-text description of an Ability ID into <paramref name="outBuffer"/>
    /// (e.g. "Powers up moves of the same type."). Empty if unknown/not yet catalogued — see
    /// Scripts/generate_ability_descriptions.py for how this supplemental data set was built,
    /// since PKHeX.Core ships no ability descriptions of its own.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_ability_get_description")]
    public static unsafe int AbilityGetDescription(ushort ability, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.abilitydescriptions;
        var description = ability < list.Length ? list[ability] : "";
        return WriteString(description, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Writes the current (English) display name of a Ball ID (see PKHeX.Core's Ball enum) into
    /// <paramref name="outBuffer"/>, e.g. "Poké Ball", "Ultra Ball".
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_ball_get_name")]
    public static unsafe int BallGetName(byte ball, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.balllist;
        var name = ball < list.Length ? list[ball] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Current PP remaining in the given move slot (0-3).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_move_pp")]
    public static int PkmGetMovePP(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return index switch { 0 => pk.Move1_PP, 1 => pk.Move2_PP, 2 => pk.Move3_PP, 3 => pk.Move4_PP, _ => -1 };
    }

    /// <summary>
    /// Maximum PP (accounting for PP Ups) for the move currently in the given slot (0-3).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_move_pp_max")]
    public static int PkmGetMovePPMax(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        var (move, ppUps) = index switch
        {
            0 => (pk.Move1, pk.Move1_PPUps),
            1 => (pk.Move2, pk.Move2_PPUps),
            2 => (pk.Move3, pk.Move3_PPUps),
            3 => (pk.Move4, pk.Move4_PPUps),
            _ => ((ushort)0, 0),
        };
        return move == 0 ? 0 : pk.GetMovePP(move, ppUps);
    }

    /// <summary>
    /// Base max PP (0 PP Ups) for an arbitrary move ID, for this PKM's game context — used by the
    /// move picker to show PP for candidate moves that aren't the one currently equipped in a slot
    /// (pkhex_pkm_get_move_pp/_pp_max only read the PKM's already-stored slots, not an arbitrary
    /// move ID). Selecting a move always resets it to full PP with no PP Ups (see
    /// pkhex_pkm_set_move), so this is exactly what a newly-selected move's PP would be.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_move_base_pp")]
    public static int PkmGetMoveBasePP(long handle, ushort move)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return move == 0 ? 0 : pk.GetMovePP(move, 0);
    }

    private static unsafe int WriteString(string value, char* outBuffer, int outBufferLength)
    {
        if (outBuffer is null || outBufferLength < value.Length)
            return value.Length;
        value.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return value.Length;
    }
}
