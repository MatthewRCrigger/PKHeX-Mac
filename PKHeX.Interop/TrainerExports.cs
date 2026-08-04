using System;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Interop;

public static class TrainerExports
{
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_ot_name")]
    public static unsafe int SaveGetOTName(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<SaveFile>(handle) is not { } sav)
            return -1;
        return WriteString(sav.OT, outBuffer, outBufferLength);
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_set_ot_name")]
    public static unsafe void SaveSetOTName(long handle, char* name, int length)
    {
        if (HandleTable.Get<SaveFile>(handle) is not { } sav)
            return;
        sav.OT = new string(new ReadOnlySpan<char>(name, length));
    }

    /// <summary>
    /// Maximum OT name length (in characters) for the loaded save's generation/language.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_max_ot_name_length")]
    public static int SaveGetMaxOTNameLength(long handle) => HandleTable.Get<SaveFile>(handle)?.MaxStringLengthTrainer ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_tid")]
    public static ushort SaveGetTID(long handle) => HandleTable.Get<SaveFile>(handle)?.TID16 ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_set_tid")]
    public static void SaveSetTID(long handle, ushort tid)
    {
        if (HandleTable.Get<SaveFile>(handle) is { } sav)
            sav.TID16 = tid;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_sid")]
    public static ushort SaveGetSID(long handle) => HandleTable.Get<SaveFile>(handle)?.SID16 ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_set_sid")]
    public static void SaveSetSID(long handle, ushort sid)
    {
        if (HandleTable.Get<SaveFile>(handle) is { } sav)
            sav.SID16 = sid;
    }

    /// <summary>0 = male, 1 = female.</summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_trainer_gender")]
    public static byte SaveGetTrainerGender(long handle) => HandleTable.Get<SaveFile>(handle)?.Gender ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_set_trainer_gender")]
    public static void SaveSetTrainerGender(long handle, byte gender)
    {
        if (HandleTable.Get<SaveFile>(handle) is { } sav)
            sav.Gender = gender;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_money")]
    public static uint SaveGetMoney(long handle) => HandleTable.Get<SaveFile>(handle)?.Money ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_set_money")]
    public static void SaveSetMoney(long handle, uint money)
    {
        if (HandleTable.Get<SaveFile>(handle) is { } sav)
            sav.Money = money;
    }

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_max_money")]
    public static int SaveGetMaxMoney(long handle) => HandleTable.Get<SaveFile>(handle)?.MaxMoney ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_played_hours")]
    public static int SaveGetPlayedHours(long handle) => HandleTable.Get<SaveFile>(handle)?.PlayedHours ?? 0;

    [UnmanagedCallersOnly(EntryPoint = "pkhex_save_get_played_minutes")]
    public static int SaveGetPlayedMinutes(long handle) => HandleTable.Get<SaveFile>(handle)?.PlayedMinutes ?? 0;

    private static unsafe int WriteString(string value, char* outBuffer, int outBufferLength)
    {
        if (outBuffer is null || outBufferLength < value.Length)
            return value.Length;
        value.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return value.Length;
    }
}
