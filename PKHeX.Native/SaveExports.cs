using System;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Native;

public static class SaveExports
{
    /// <summary>
    /// Loads a save file from raw bytes. Returns a handle &gt; 0 on success, or 0 if the data
    /// isn't a recognized save format.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_load")]
    public static unsafe long SaveLoad(byte* data, int length)
    {
        var span = new ReadOnlySpan<byte>(data, length);
        var buffer = span.ToArray();
        var sav = SaveUtil.GetSaveFile(buffer);
        return sav is null ? 0 : HandleTable.Add(sav);
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_close")]
    public static void SaveClose(long handle) => HandleTable.Remove(handle);

    /// <summary>
    /// Serializes the save back to bytes (with checksums fixed up), writing the result into
    /// <paramref name="outBuffer"/>. Returns the required length; if <paramref name="outBuffer"/>
    /// is too small (or null), returns the required length and writes nothing, so callers should
    /// call once with a null buffer to size their allocation, then again to fill it.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_write")]
    public static unsafe int SaveWrite(long handle, byte* outBuffer, int outBufferLength)
    {
        var sav = HandleTable.Get<SaveFile>(handle);
        if (sav is null)
            return -1;

        var flags = sav.Metadata.GetSuggestedFlags(sav.Extension);
        var bytes = sav.Write(flags);
        if (outBuffer is null || outBufferLength < bytes.Length)
            return bytes.Length;

        bytes.Span.CopyTo(new Span<byte>(outBuffer, outBufferLength));
        return bytes.Length;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_box_count")]
    public static int SaveGetBoxCount(long handle) => HandleTable.Get<SaveFile>(handle)?.BoxCount ?? -1;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_box_slot_count")]
    public static int SaveGetBoxSlotCount(long handle) => HandleTable.Get<SaveFile>(handle)?.BoxSlotCount ?? -1;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_generation")]
    public static byte SaveGetGeneration(long handle) => HandleTable.Get<SaveFile>(handle)?.Generation ?? 0;

    /// <summary>
    /// Writes the display name of this save's game version (e.g. "Crystal", "Platinum",
    /// "HeartGold") into <paramref name="outBuffer"/>. Returns the required length in chars; call
    /// once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_game_name")]
    public static unsafe int SaveGetGameName(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<SaveFile>(handle) is not { } sav)
            return -1;
        var list = GameInfo.Strings.gamelist;
        var index = (int)sav.Version;
        var name = index >= 0 && index < list.Length ? list[index] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>Highest valid species ID for this save's game/generation.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_max_species_id")]
    public static ushort SaveGetMaxSpeciesId(long handle) => HandleTable.Get<SaveFile>(handle)?.MaxSpeciesID ?? 0;

    /// <summary>Number of species this save's Pokedex records as seen.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_dex_seen_count")]
    public static int SaveGetDexSeenCount(long handle) => HandleTable.Get<SaveFile>(handle)?.SeenCount ?? 0;

    /// <summary>Number of species this save's Pokedex records as caught/owned.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_dex_caught_count")]
    public static int SaveGetDexCaughtCount(long handle) => HandleTable.Get<SaveFile>(handle)?.CaughtCount ?? 0;

    /// <summary>True if this save format tracks a Pokedex at all.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_has_pokedex")]
    public static byte SaveHasPokedex(long handle) => (byte)(HandleTable.Get<SaveFile>(handle)?.HasPokeDex == true ? 1 : 0);

    /// <summary>
    /// Writes the display name of the given box (0-indexed) into <paramref name="outBuffer"/>.
    /// Falls back to "Box N" if this save format doesn't track custom box names.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_box_name")]
    public static unsafe int SaveGetBoxName(long handle, int box, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<SaveFile>(handle) is not { } sav)
            return -1;
        var name = sav is IBoxDetailNameRead n ? n.GetBoxName(box) : BoxDetailNameExtensions.GetDefaultBoxName(box);
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// Creates a new blank-template PKM of the given species (legal empty EVs/IVs/moveset for a
    /// levelup-legal Pokemon at level 1), ready to be placed into a slot with pkhex_save_set_slot
    /// or pkhex_save_set_party_slot. Returns a handle &gt; 0, or 0 on failure; release with
    /// pkhex_pkm_close like any other PKM handle.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_create_blank_pkm")]
    public static long SaveCreateBlankPkm(long handle, ushort species)
    {
        if (HandleTable.Get<SaveFile>(handle) is not { } sav || species == 0 || species > sav.MaxSpeciesID)
            return 0;
        var pk = sav.BlankPKM;
        pk.Species = species;
        pk.CurrentLevel = 1;
        pk.Nickname = GameInfo.Strings.specieslist[species];
        pk.Language = sav.Language > 0 ? sav.Language : 2; // fall back to English
        pk.OriginalTrainerName = sav.OT;
        pk.TID16 = sav.TID16;
        pk.SID16 = sav.SID16;
        pk.OriginalTrainerGender = sav.Gender;
        pk.RefreshChecksum();
        return HandleTable.Add(pk);
    }

    /// <summary>
    /// Clears a box slot back to empty (writes the save's blank/species-0 template), matching how
    /// the official editor's "Delete" action works. No-op (returns 0) if the save handle or
    /// box/slot coordinates are invalid.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_clear_slot")]
    public static int SaveClearSlot(long handle, int box, int slot)
    {
        var sav = HandleTable.Get<SaveFile>(handle);
        if (sav is null || box < 0 || box >= sav.BoxCount || slot < 0 || slot >= sav.BoxSlotCount)
            return -1;
        sav.SetBoxSlotAtIndex(sav.BlankPKM, box, slot);
        return 0;
    }

    /// <summary>
    /// Clears a party slot back to empty. Unlike box slots, party members must stay contiguous
    /// from index 0 (no gaps), so this slides every following party member down one slot and
    /// clears the vacated last slot, matching the official editor's "Delete" action
    /// (SaveFile.DeletePartySlot) rather than just blanking the slot in place.
    /// No-op (returns -1) if the save handle or party index is invalid.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_clear_party_slot")]
    public static int SaveClearPartySlot(long handle, int index)
    {
        var sav = HandleTable.Get<SaveFile>(handle);
        if (sav is null || index < 0 || index >= sav.PartyCount)
            return -1;
        sav.DeletePartySlot(index);
        return 0;
    }

    /// <summary>
    /// Returns a handle to the PKM at the given box/slot (0-indexed), or 0 if the slot is empty
    /// or the save handle is invalid. The returned PKM handle must be released with pkm_close.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_slot")]
    public static long SaveGetSlot(long handle, int box, int slot)
    {
        var sav = HandleTable.Get<SaveFile>(handle);
        if (sav is null || box < 0 || box >= sav.BoxCount || slot < 0 || slot >= sav.BoxSlotCount)
            return 0;

        var pk = sav.GetBoxSlotAtIndex(box, slot);
        return pk.Species == 0 ? 0 : HandleTable.Add(pk);
    }

    /// <summary>
    /// Writes a (possibly modified) PKM back into the given box/slot.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_set_slot")]
    public static int SaveSetSlot(long saveHandle, long pkmHandle, int box, int slot)
    {
        var sav = HandleTable.Get<SaveFile>(saveHandle);
        var pk = HandleTable.Get<PKM>(pkmHandle);
        if (sav is null || pk is null || box < 0 || box >= sav.BoxCount || slot < 0 || slot >= sav.BoxSlotCount)
            return -1;

        sav.SetBoxSlotAtIndex(pk, box, slot);
        return 0;
    }

    /// <summary>
    /// Number of Pokemon currently in the party (0-6).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_party_count")]
    public static int SaveGetPartyCount(long handle) => HandleTable.Get<SaveFile>(handle)?.PartyCount ?? -1;

    /// <summary>
    /// Returns a handle to the PKM at the given party index (0-5), or 0 if the slot is empty
    /// or out of range. The returned PKM handle must be released with pkm_close.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_party_slot")]
    public static long SaveGetPartySlot(long handle, int index)
    {
        var sav = HandleTable.Get<SaveFile>(handle);
        if (sav is null || index < 0 || index >= sav.PartyCount)
            return 0;

        var pk = sav.GetPartySlotAtIndex(index);
        return pk.Species == 0 ? 0 : HandleTable.Add(pk);
    }

    /// <summary>
    /// Writes a (possibly modified) PKM back into the given party index (0-5).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_set_party_slot")]
    public static int SaveSetPartySlot(long saveHandle, long pkmHandle, int index)
    {
        var sav = HandleTable.Get<SaveFile>(saveHandle);
        var pk = HandleTable.Get<PKM>(pkmHandle);
        if (sav is null || pk is null || index < 0 || index >= sav.PartyCount)
            return -1;

        sav.SetPartySlotAtIndex(pk, index);
        return 0;
    }

    private static unsafe int WriteString(string value, char* outBuffer, int outBufferLength)
    {
        if (outBuffer is null || outBufferLength < value.Length)
            return value.Length;
        value.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return value.Length;
    }
}
