using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Interop;

public static class BagExports
{
    /// <summary>
    /// Tracks the (EntityContext, Version) of the save each bag handle was loaded from, since item
    /// names for Gen 1/2/3 saves must be resolved through GameInfo.Strings.GetItemStrings(context,
    /// version) rather than the shared/modern GameInfo.Strings.itemlist — those generations store
    /// item ids using their own legacy internal numbering, not the modern shared id space.
    /// </summary>
    private static readonly Dictionary<long, (EntityContext Context, GameVersion Version)> BagContext = new();

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
        var handle = HandleTable.Add(sav.Inventory);
        BagContext[handle] = (sav.Context, sav.Version);
        return handle;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_close")]
    public static void BagClose(long handle)
    {
        HandleTable.Remove(handle);
        BagContext.Remove(handle);
    }

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

    /// <summary>
    /// True if this pouch has fewer slots than legal item IDs (e.g. Gen 1-3's small free-form
    /// bags), meaning slots must be assigned to whichever items the player is carrying rather
    /// than having one dedicated slot per possible item.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_pouch_is_cramped")]
    public static int BagGetPouchIsCramped(long handle, int pouchIndex)
    {
        var bag = HandleTable.Get<PlayerBag>(handle);
        if (bag is null || pouchIndex < 0 || pouchIndex >= bag.Pouches.Count)
            return -1;
        return bag.Pouches[pouchIndex].IsCramped ? 1 : 0;
    }

    /// <summary>
    /// Number of item IDs that are legal to carry in this pouch.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_pouch_legal_item_count")]
    public static int BagGetPouchLegalItemCount(long handle, int pouchIndex)
    {
        var bag = HandleTable.Get<PlayerBag>(handle);
        if (bag is null || pouchIndex < 0 || pouchIndex >= bag.Pouches.Count)
            return -1;
        return bag.Pouches[pouchIndex].GetAllItems().Length;
    }

    /// <summary>
    /// The item ID at the given index into this pouch's legal-item list (see
    /// pkhex_bag_get_pouch_legal_item_count).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_pouch_legal_item")]
    public static int BagGetPouchLegalItem(long handle, int pouchIndex, int itemListIndex)
    {
        var bag = HandleTable.Get<PlayerBag>(handle);
        if (bag is null || pouchIndex < 0 || pouchIndex >= bag.Pouches.Count)
            return -1;
        var items = bag.Pouches[pouchIndex].GetAllItems();
        if (itemListIndex < 0 || itemListIndex >= items.Length)
            return -1;
        return items[itemListIndex];
    }

    /// <summary>
    /// Finds the first empty slot in the pouch and sets it to the given item/count. Returns the
    /// slot index used, or -1 if the pouch is full or the pouch/item is invalid.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_add_item")]
    public static int BagAddItem(long handle, int pouchIndex, int itemIndex, int count)
    {
        var bag = HandleTable.Get<PlayerBag>(handle);
        if (bag is null || pouchIndex < 0 || pouchIndex >= bag.Pouches.Count || itemIndex == 0)
            return -1;
        var pouch = bag.Pouches[pouchIndex];
        var items = pouch.Items;
        for (var slot = 0; slot < items.Length; slot++)
        {
            if (items[slot].Index != 0)
                continue;
            items[slot].Index = itemIndex;
            items[slot].Count = count;
            return slot;
        }
        return -1;
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

    /// <summary>
    /// Writes the display name of an item index as stored in this bag's pouches (i.e. as returned
    /// by pkhex_bag_get_item_index / pkhex_bag_get_pouch_legal_item) into <paramref name="outBuffer"/>.
    /// Unlike pkhex_item_get_name, this resolves through the bag's originating save's generation
    /// context, which is required for Gen 1-3 saves: those store item ids using their own legacy
    /// internal numbering (not the shared/modern id space pkhex_item_get_name assumes), so passing
    /// a Gen 1-3 pouch's raw item index to pkhex_item_get_name returns the wrong name entirely.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_bag_get_item_name")]
    public static unsafe int BagGetItemName(long bagHandle, ushort item, char* outBuffer, int outBufferLength)
    {
        var list = BagContext.TryGetValue(bagHandle, out var ctx)
            ? GameInfo.Strings.GetItemStrings(ctx.Context, ctx.Version)
            : GameInfo.Strings.itemlist;
        var name = item < list.Length ? list[item] : "";
        if (outBuffer is null || outBufferLength < name.Length)
            return name.Length;
        name.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return name.Length;
    }
}
