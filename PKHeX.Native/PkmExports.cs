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

    // Moves: index 0-3.
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_move")]
    public static ushort PkmGetMove(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        return index switch { 0 => pk.Move1, 1 => pk.Move2, 2 => pk.Move3, 3 => pk.Move4, _ => 0 };
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_move")]
    public static void PkmSetMove(long handle, int index, ushort move)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        switch (index)
        {
            case 0: pk.Move1 = move; break;
            case 1: pk.Move2 = move; break;
            case 2: pk.Move3 = move; break;
            case 3: pk.Move4 = move; break;
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
        if (outBuffer is null || outBufferLength < name.Length)
            return name.Length;
        name.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return name.Length;
    }
}
