using System;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Interop;

/// <summary>
/// Cross-save/cross-generation PKM conversion, for dragging or pasting a Pokemon from one open
/// save into another of a different generation (mirrors PKHeX.WinForms' Main.OpenPKM /
/// SlotChangeManager.TryLoadFiles, which call EntityConverter.ConvertToType keyed off the
/// destination save's PKMType). Same-generation moves never need this — see pkhex_save_set_slot.
/// </summary>
public static class EntityConverterExports
{
    /// <summary>
    /// Attempts to convert a PKM to the format required by a destination save (its PKMType), e.g.
    /// Gen 3 -> Gen 4, or a 3DS Virtual Console Gen 1/2 entity -> Gen 7. Returns a handle to the
    /// converted PKM (release with pkhex_pkm_close) ready for pkhex_save_set_slot/
    /// pkhex_save_set_party_slot on the SAME destination save, or 0 if no legal conversion path
    /// exists (wrong direction, incompatible species/form, or a GB-language mismatch) — call
    /// pkhex_pkm_get_convert_error for why. Does not mutate the input PKM or destination save.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_convert_to_save")]
    public static long PkmConvertToSave(long pkmHandle, long destSaveHandle)
    {
        if (HandleTable.Get<PKM>(pkmHandle) is not { } pk || HandleTable.Get<SaveFile>(destSaveHandle) is not { } dest)
            return 0;

        var converted = ConvertForDestination(pk, dest, out _);
        return converted is null ? 0 : HandleTable.Add(converted);
    }

    /// <summary>
    /// True if pkhex_pkm_convert_to_save would succeed for this PKM/destination-save pair, without
    /// allocating a handle for the result. Cheap to call speculatively (e.g. while dragging, before
    /// a drop actually happens) to decide whether to show a valid-drop vs. blocked-drop cursor.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_can_convert_to_save")]
    public static byte PkmCanConvertToSave(long pkmHandle, long destSaveHandle)
    {
        if (HandleTable.Get<PKM>(pkmHandle) is not { } pk || HandleTable.Get<SaveFile>(destSaveHandle) is not { } dest)
            return 0;

        return (byte)(ConvertForDestination(pk, dest, out _) is null ? 0 : 1);
    }

    /// <summary>
    /// Human-readable reason the most recent conversion for this PKM/destination-save pair would
    /// fail (or "" if it would succeed) — same wording PKHeX.WinForms shows (EntityConverterResult.
    /// GetDisplayString), e.g. "Cannot convert PK4 to PK3." or a GB-language incompatibility
    /// message. Re-runs the conversion attempt (no cached error state) so it's safe to call any
    /// time, independent of whether pkhex_pkm_convert_to_save was ever called for this pair.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_convert_error")]
    public static unsafe int PkmGetConvertError(long pkmHandle, long destSaveHandle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(pkmHandle) is not { } pk || HandleTable.Get<SaveFile>(destSaveHandle) is not { } dest)
            return -1;

        var converted = ConvertForDestination(pk, dest, out var message);
        var text = converted is null ? message : "";
        if (outBuffer is null || outBufferLength < text.Length)
            return text.Length;
        text.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return text.Length;
    }

    /// <summary>
    /// Runs the same sequence PKHeX.WinForms' file-drop handler uses: convert to the destination's
    /// PKMType, then reject GB-era (Gen 1/2) language mismatches ConvertToType alone doesn't catch.
    /// </summary>
    private static PKM? ConvertForDestination(PKM pk, SaveFile dest, out string message)
    {
        var destType = dest.PKMType;
        var converted = EntityConverter.ConvertToType(pk, destType, out var result);
        if (converted is null)
        {
            message = result.GetDisplayString(pk, destType);
            return null;
        }

        if (dest is ILangDeviantSave il && !EntityConverter.IsCompatibleGB(converted, il.Japanese, pk.Japanese))
        {
            message = EntityConverterResult.IncompatibleLanguageGB.GetIncompatibleGBMessage(converted, il.Japanese);
            return null;
        }

        message = "";
        return converted;
    }
}
