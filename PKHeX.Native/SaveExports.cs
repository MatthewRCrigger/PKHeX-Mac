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
}
