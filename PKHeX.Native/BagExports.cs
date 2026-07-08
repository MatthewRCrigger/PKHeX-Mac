using System;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Native;

public static class BagExports
{
    /// <summary>
    /// Loads a snapshot of the save's bag. Returns a handle &gt; 0, or 0 if the save handle is
    /// invalid. Edits to items are made on this snapshot and are not persisted to the save until
    /// pkhex_bag_commit is called. Release with pkhex_bag_close.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_load")]
    public static long BagLoad(long saveHandle)
    {
        if (HandleTable.Get<SaveFile>(saveHandle) is not { } sav)
            return 0;
        return HandleTable.Add(sav.Inventory);
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_close")]
    public static void BagClose(long handle) => HandleTable.Remove(handle);

    /// <summary>
    /// Writes the bag snapshot's current item contents back into the save. Does not itself
    /// serialize the save to disk; call pkhex_save_write afterward for that.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_commit")]
    public static int BagCommit(long bagHandle, long saveHandle)
    {
        var bag = HandleTable.Get<PlayerBag>(bagHandle);
        var sav = HandleTable.Get<SaveFile>(saveHandle);
        if (bag is null || sav is null)
            return -1;
        bag.CopyTo(sav);
        return 0;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_pouch_count")]
    public static int BagGetPouchCount(long handle) => HandleTable.Get<PlayerBag>(handle)?.Pouches.Count ?? -1;

    /// <summary>
    /// Underlying InventoryType enum value for the pouch at the given index.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_pouch_type")]
    public static int BagGetPouchType(long handle, int pouchIndex)
    {
        var bag = HandleTable.Get<PlayerBag>(handle);
        if (bag is null || pouchIndex < 0 || pouchIndex >= bag.Pouches.Count)
            return -1;
        return (int)bag.Pouches[pouchIndex].Type;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_pouch_slot_count")]
    public static int BagGetPouchSlotCount(long handle, int pouchIndex)
    {
        var bag = HandleTable.Get<PlayerBag>(handle);
        if (bag is null || pouchIndex < 0 || pouchIndex >= bag.Pouches.Count)
            return -1;
        return bag.Pouches[pouchIndex].Items.Length;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_item_index")]
    public static int BagGetItemIndex(long handle, int pouchIndex, int slot)
    {
        if (!TryGetItem(handle, pouchIndex, slot, out var item))
            return -1;
        return item.Index;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_item_count")]
    public static int BagGetItemCount(long handle, int pouchIndex, int slot)
    {
        if (!TryGetItem(handle, pouchIndex, slot, out var item))
            return -1;
        return item.Count;
    }

    /// <summary>
    /// Sets the item and quantity for a bag slot. Pass itemIndex 0 to clear the slot.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_set_item")]
    public static int BagSetItem(long handle, int pouchIndex, int slot, int itemIndex, int count)
    {
        if (!TryGetItem(handle, pouchIndex, slot, out var item))
            return -1;
        item.Index = itemIndex;
        item.Count = itemIndex == 0 ? 0 : count;
        return 0;
    }

    private static bool TryGetItem(long handle, int pouchIndex, int slot, out InventoryItem item)
    {
        item = null!;
        var bag = HandleTable.Get<PlayerBag>(handle);
        if (bag is null || pouchIndex < 0 || pouchIndex >= bag.Pouches.Count)
            return false;
        var pouch = bag.Pouches[pouchIndex];
        if (slot < 0 || slot >= pouch.Items.Length)
            return false;
        item = pouch.Items[slot];
        return true;
    }

    /// <summary>
    /// Writes the current (English) display name of an item ID into <paramref name="outBuffer"/>.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_item_get_name")]
    public static unsafe int ItemGetName(ushort item, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.itemlist;
        var name = item < list.Length ? list[item] : "";
        if (outBuffer is null || outBufferLength < name.Length)
            return name.Length;
        name.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return name.Length;
    }
}
