using System;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Native;

/// <summary>
/// Per-Pokemon Original Trainer / Handling Trainer / Memory exports. Distinct from
/// TrainerExports.cs, which bridges the SAVE FILE's own trainer identity (the player) — these
/// bridge the OT/HT stamped onto an individual PKM, which may differ from the save's own trainer
/// once a Pokemon has been traded.
/// </summary>
public static class PkmTrainerExports
{
    // --- Original Trainer ---

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ot_name")]
    public static unsafe int PkmGetOtName(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return WriteString(pk.OriginalTrainerName, outBuffer, outBufferLength);
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ot_name")]
    public static unsafe void PkmSetOtName(long handle, char* name, int length)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        pk.OriginalTrainerName = new string(new ReadOnlySpan<char>(name, length));
    }

    /// <summary>Maximum OT name length (in characters) for this PKM's generation/language.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_max_ot_name_length")]
    public static int PkmGetMaxOtNameLength(long handle) => HandleTable.Get<PKM>(handle)?.MaxStringLengthTrainer ?? 0;

    /// <summary>0 = male, 1 = female.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ot_gender")]
    public static byte PkmGetOtGender(long handle) => HandleTable.Get<PKM>(handle)?.OriginalTrainerGender ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ot_gender")]
    public static void PkmSetOtGender(long handle, byte gender)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.OriginalTrainerGender = gender;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ot_friendship")]
    public static byte PkmGetOtFriendship(long handle) => HandleTable.Get<PKM>(handle)?.OriginalTrainerFriendship ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ot_friendship")]
    public static void PkmSetOtFriendship(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.OriginalTrainerFriendship = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_tid16")]
    public static ushort PkmGetTid16(long handle) => HandleTable.Get<PKM>(handle)?.TID16 ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_tid16")]
    public static void PkmSetTid16(long handle, ushort tid)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.TID16 = tid;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_sid16")]
    public static ushort PkmGetSid16(long handle) => HandleTable.Get<PKM>(handle)?.SID16 ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_sid16")]
    public static void PkmSetSid16(long handle, ushort sid)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.SID16 = sid;
    }

    /// <summary>
    /// Resets this PKM's OT name/gender/TID/SID/language to match the given save file's own
    /// trainer identity — i.e. "this Pokemon was always mine," undoing any trade history stamped
    /// into its OT fields. Does not touch Handling Trainer fields or memories; pair with
    /// pkhex_pkm_set_current_handler(0) and pkhex_pkm_clear_memories() for a full "make this
    /// Pokemon look untraded" reset.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_reset_ot_to_save_trainer")]
    public static void PkmResetOtToSaveTrainer(long pkmHandle, long saveHandle)
    {
        if (HandleTable.Get<PKM>(pkmHandle) is not { } pk || HandleTable.Get<SaveFile>(saveHandle) is not { } sav)
            return;
        pk.OriginalTrainerName = sav.OT;
        pk.OriginalTrainerGender = sav.Gender;
        pk.TID16 = sav.TID16;
        pk.SID16 = sav.SID16;
        pk.Language = sav.Language;
    }

    // --- Handling Trainer ---

    /// <summary>
    /// True if this PKM's format has any Handling Trainer concept at all (Gen 6+ — pre-Gen6
    /// formats predate the "current handler" mechanic entirely and HandlingTrainerName is a
    /// harmless no-op there). Gate Handling Trainer UI on this.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_supports_handling_trainer")]
    public static byte PkmGetSupportsHandlingTrainer(long handle) => (byte)((HandleTable.Get<PKM>(handle)?.Format ?? 0) >= 6 ? 1 : 0);

    /// <summary>
    /// True if this PKM currently has Handling Trainer data set at all (i.e. it's been traded at
    /// least once) — mirrors PKHeX.WinForms' rule for whether to show the HT UI at all
    /// (LoadSave.cs's ToggleHandlerVisibility: HT UI only appears once HandlingTrainerName is
    /// non-empty). Distinct from pkhex_pkm_get_current_handler, which says who currently holds it.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_has_handling_trainer")]
    public static byte PkmGetHasHandlingTrainer(long handle) => (byte)(string.IsNullOrEmpty(HandleTable.Get<PKM>(handle)?.HandlingTrainerName) ? 0 : 1);

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ht_name")]
    public static unsafe int PkmGetHtName(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return WriteString(pk.HandlingTrainerName, outBuffer, outBufferLength);
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ht_name")]
    public static unsafe void PkmSetHtName(long handle, char* name, int length)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return;
        pk.HandlingTrainerName = new string(new ReadOnlySpan<char>(name, length));
    }

    /// <summary>0 = male, 1 = female.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ht_gender")]
    public static byte PkmGetHtGender(long handle) => HandleTable.Get<PKM>(handle)?.HandlingTrainerGender ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ht_gender")]
    public static void PkmSetHtGender(long handle, byte gender)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.HandlingTrainerGender = gender;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ht_friendship")]
    public static byte PkmGetHtFriendship(long handle) => HandleTable.Get<PKM>(handle)?.HandlingTrainerFriendship ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ht_friendship")]
    public static void PkmSetHtFriendship(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.HandlingTrainerFriendship = value;
    }

    /// <summary>0 = Original Trainer currently possesses it, 1 = Handling Trainer does (traded).</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_current_handler")]
    public static byte PkmGetCurrentHandler(long handle) => HandleTable.Get<PKM>(handle)?.CurrentHandler ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_current_handler")]
    public static void PkmSetCurrentHandler(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.CurrentHandler = value;
    }

    // --- Memories (Gen 6+, except Let's Go Pikachu/Eevee which drops the OT side entirely) ---

    /// <summary>
    /// True if this PKM's format tracks Original Trainer memories at all. Gen 6-9 track them
    /// except Let's Go Pikachu/Eevee (format 7 but PB7 doesn't implement the memory interface —
    /// Let's Go dropped the Amie/memory mechanic), and PLA/Legends Z-A (PA8/PA9) which do carry
    /// the interface. Gate OT Memory UI on this rather than format >= 6 alone.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_supports_ot_memory")]
    public static byte PkmGetSupportsOtMemory(long handle) => (byte)(HandleTable.Get<PKM>(handle) is IMemoryOT ? 1 : 0);

    /// <summary>
    /// True if this PKM's format tracks Handling Trainer memories. Unlike OT memories, Let's Go
    /// (PB7) does have HT memory fields (just not through the standard IMemoryHT interface, and
    /// not exposed here since PB7 support isn't otherwise implemented in this bridge) — every
    /// format from Gen 6 on that supports a Handling Trainer at all also tracks their memory.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_supports_ht_memory")]
    public static byte PkmGetSupportsHtMemory(long handle) => (byte)(HandleTable.Get<PKM>(handle) is IMemoryHT ? 1 : 0);

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ot_memory")]
    public static byte PkmGetOtMemory(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryOT)?.OriginalTrainerMemory ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ot_memory")]
    public static void PkmSetOtMemory(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryOT ot)
            ot.OriginalTrainerMemory = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ot_memory_intensity")]
    public static byte PkmGetOtMemoryIntensity(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryOT)?.OriginalTrainerMemoryIntensity ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ot_memory_intensity")]
    public static void PkmSetOtMemoryIntensity(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryOT ot)
            ot.OriginalTrainerMemoryIntensity = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ot_memory_feeling")]
    public static byte PkmGetOtMemoryFeeling(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryOT)?.OriginalTrainerMemoryFeeling ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ot_memory_feeling")]
    public static void PkmSetOtMemoryFeeling(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryOT ot)
            ot.OriginalTrainerMemoryFeeling = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ot_memory_variable")]
    public static ushort PkmGetOtMemoryVariable(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryOT)?.OriginalTrainerMemoryVariable ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ot_memory_variable")]
    public static void PkmSetOtMemoryVariable(long handle, ushort value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryOT ot)
            ot.OriginalTrainerMemoryVariable = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ht_memory")]
    public static byte PkmGetHtMemory(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryHT)?.HandlingTrainerMemory ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ht_memory")]
    public static void PkmSetHtMemory(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryHT ht)
            ht.HandlingTrainerMemory = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ht_memory_intensity")]
    public static byte PkmGetHtMemoryIntensity(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryHT)?.HandlingTrainerMemoryIntensity ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ht_memory_intensity")]
    public static void PkmSetHtMemoryIntensity(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryHT ht)
            ht.HandlingTrainerMemoryIntensity = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ht_memory_feeling")]
    public static byte PkmGetHtMemoryFeeling(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryHT)?.HandlingTrainerMemoryFeeling ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ht_memory_feeling")]
    public static void PkmSetHtMemoryFeeling(long handle, byte value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryHT ht)
            ht.HandlingTrainerMemoryFeeling = value;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_ht_memory_variable")]
    public static ushort PkmGetHtMemoryVariable(long handle) => (HandleTable.Get<PKM>(handle) as IMemoryHT)?.HandlingTrainerMemoryVariable ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_ht_memory_variable")]
    public static void PkmSetHtMemoryVariable(long handle, ushort value)
    {
        if (HandleTable.Get<PKM>(handle) is IMemoryHT ht)
            ht.HandlingTrainerMemoryVariable = value;
    }

    /// <summary>Zeroes OT + HT memory fields (PKM.ClearMemories()).</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_clear_memories")]
    public static void PkmClearMemories(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is { } pk)
            pk.ClearMemories();
    }

    /// <summary>
    /// Number of valid Memory IDs for this PKM's context (0..&lt;count), for building a memory
    /// picker. Memory ID 0 ("None"/no memory) is included.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_memory_id_count")]
    public static int PkmGetMemoryIdCount(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        var context = Memories.GetContext(pk.Context);
        var count = 0;
        for (byte memory = 0; memory < 90; memory++)
        {
            if (memory == 0 || context.CanObtainMemory(memory))
                count++;
        }
        return count;
    }

    /// <summary>Memory ID at the given index of the list sized by pkhex_pkm_get_memory_id_count.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_memory_id_at_index")]
    public static byte PkmGetMemoryIdAtIndex(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        var context = Memories.GetContext(pk.Context);
        var seen = 0;
        for (byte memory = 0; memory < 90; memory++)
        {
            if (memory != 0 && !context.CanObtainMemory(memory))
                continue;
            if (seen == index)
                return memory;
            seen++;
        }
        return 0;
    }

    /// <summary>
    /// Display text for a memory ID, e.g. "{0} caught {2} at {1}. {4} that Pokémon was really
    /// strong." — the {N} placeholders are filled in by pkhex_pkm_get_memory_sentence, this is
    /// just the raw sentence line for building a memory-id picker's option labels.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_memory_get_line")]
    public static unsafe int MemoryGetLine(byte memoryId, char* outBuffer, int outBufferLength)
    {
        var list = GameInfo.Strings.memories;
        var name = memoryId < list.Length ? list[memoryId] : "";
        return WriteString(name, outBuffer, outBufferLength);
    }

    /// <summary>
    /// The kind of value pkhex_pkm_get/set_ot_memory_variable (or ht_memory_variable) means for
    /// the given memory ID: 0=None, 1=GeneralLocation, 2=SpecificLocation, 3=Species, 4=Move,
    /// 5=Item (matches PKHeX.Core's MemoryArgType enum ordinal). Use to decide which picker to
    /// show for the "variable" field (a location list, species list, move list, or item list).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_memory_get_variable_arg_type")]
    public static byte MemoryGetVariableArgType(long handle, byte memoryId)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        return (byte)Memories.GetMemoryArgType(memoryId, pk.Format);
    }

    /// <summary>
    /// Display name for a memory's "variable" value, resolved according to
    /// pkhex_memory_get_variable_arg_type (e.g. a location name, species name, move name, or item
    /// name as appropriate) — for showing e.g. "Route 5" instead of a bare numeric TextVar.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_memory_get_variable_name")]
    public static unsafe int MemoryGetVariableName(long handle, byte memoryId, ushort variable, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        var argType = Memories.GetMemoryArgType(memoryId, pk.Format);
        var strings = GameInfo.Strings;
        var name = argType switch
        {
            MemoryArgType.GeneralLocation or MemoryArgType.SpecificLocation =>
                GetLocationName(pk, variable),
            MemoryArgType.Species => variable < strings.specieslist.Length ? strings.specieslist[variable] : "",
            MemoryArgType.Move => variable < strings.movelist.Length ? strings.movelist[variable] : "",
            MemoryArgType.Item => variable < strings.itemlist.Length ? strings.itemlist[variable] : "",
            _ => "",
        };
        return WriteString(name, outBuffer, outBufferLength);
    }

    private static string GetLocationName(PKM pk, ushort locationId)
    {
        var list = GameInfo.GetLocationList(pk.Version, pk.Context, false);
        foreach (var item in list)
        {
            if (item.Value == locationId)
                return item.Text;
        }
        return "";
    }

    /// <summary>Lowest legal Intensity value for a given memory ID.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_memory_get_minimum_intensity")]
    public static byte MemoryGetMinimumIntensity(long handle, byte memoryId)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 1;
        return Memories.GetContext(pk.Context).GetMinimumIntensity(memoryId);
    }

    /// <summary>
    /// Sets a known-legal "arrived via Link Trade" Handling Trainer memory — the same values
    /// PKHeX.WinForms suggests when a trade is detected. Convenience for a "suggest a memory"
    /// button rather than requiring the user to hand-pick legal Intensity/Feeling combinations.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_set_trade_memory_ht")]
    public static void PkmSetTradeMemoryHt(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not IMemoryHT ht)
            return;
        if (HandleTable.Get<PKM>(handle)!.Context == EntityContext.Gen6)
            ht.SetTradeMemoryHT6(bank: false);
        else
            ht.SetTradeMemoryHT8();
    }

    private static unsafe int WriteString(string value, char* outBuffer, int outBufferLength)
    {
        if (outBuffer is null || outBufferLength < value.Length)
            return value.Length;
        value.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return value.Length;
    }
}
