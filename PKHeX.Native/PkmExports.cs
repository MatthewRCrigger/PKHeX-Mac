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

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_held_item")]
    public static ushort PkmGetHeldItem(long handle) => (ushort)(HandleTable.Get<PKM>(handle)?.HeldItem ?? 0);

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_held_item")]
    public static void PkmSetHeldItem(long handle, ushort item)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.HeldItem = item;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ability")]
    public static ushort PkmGetAbility(long handle) => (ushort)(HandleTable.Get<PKM>(handle)?.Ability ?? 0);

    /// <summary>Primary type ID (see pkhex_type_get_name).</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_type1")]
    public static byte PkmGetType1(long handle) => HandleTable.Get<PKM>(handle)?.PersonalInfo.Type1 ?? 0;

    /// <summary>Secondary type ID, equal to Type1 if the species has only one type.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_type2")]
    public static byte PkmGetType2(long handle) => HandleTable.Get<PKM>(handle)?.PersonalInfo.Type2 ?? 0;

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

    private static unsafe int WriteString(string value, char* outBuffer, int outBufferLength)
    {
        if (outBuffer is null || outBufferLength < value.Length)
            return value.Length;
        value.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return value.Length;
    }
}
