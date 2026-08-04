using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Interop;

public static class LegalityExports
{
    /// <summary>
    /// Returns 1 if the PKM is legal, 0 if illegal, -1 if the handle is invalid.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_is_legal")]
    public static int PkmIsLegal(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        var la = new LegalityAnalysis(pk);
        return la.Valid ? 1 : 0;
    }

    /// <summary>
    /// Writes a human-readable legality report as UTF-16 into <paramref name="outBuffer"/> (length in chars).
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legality_report")]
    public static unsafe int PkmGetLegalityReport(long handle, char* outBuffer, int outBufferLength, byte verbose)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        var la = new LegalityAnalysis(pk);
        var report = la.Report(verbose != 0);
        if (outBuffer is null || outBufferLength < report.Length)
            return report.Length;
        report.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return report.Length;
    }

    /// <summary>
    /// Writes the human-readable legality report (same text as pkhex_pkm_get_legality_report with
    /// verbose off), one reason per line, into <paramref name="outBuffer"/>. Empty if legal.
    /// Intended for callers that want to show just the first line/reason in a UI banner.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legality_lines")]
    public static unsafe int PkmGetLegalityLines(long handle, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        var la = new LegalityAnalysis(pk);
        var report = la.Valid ? "" : la.Report(false);
        if (outBuffer is null || outBufferLength < report.Length)
            return report.Length;
        report.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return report.Length;
    }

    /// <summary>
    /// Number of individual legality check results for this PKM (both valid and invalid — filter
    /// client-side on severity, mirroring LegalityAnalysis.Results). Building block for a granular
    /// "here's what's wrong" UI, as opposed to pkhex_pkm_get_legality_lines' flat text report.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legality_result_count")]
    public static int PkmGetLegalityResultCount(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        return new LegalityAnalysis(pk).Results.Count;
    }

    /// <summary>
    /// Severity of the legality result at the given index (see pkhex_pkm_get_legality_result_count):
    /// -1 = Invalid, 0 = Fishy, 1 = Valid. Matches PKHeX.Core's Severity enum values exactly.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legality_result_severity")]
    public static sbyte PkmGetLegalityResultSeverity(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 1;
        var results = new LegalityAnalysis(pk).Results;
        return (uint)index < (uint)results.Count ? (sbyte)results[index].Judgement : (sbyte)1;
    }

    /// <summary>
    /// Category of the legality result at the given index — matches PKHeX.Core's CheckIdentifier
    /// enum ordinal (e.g. Trainer, Memory, Ball, Nature, Ability, Egg, Handler, ...). Use to group
    /// results in a UI (e.g. all Memory-category issues together) and to decide which quick-fix
    /// action applies (see pkhex_pkm_apply_legality_fix).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legality_result_identifier")]
    public static byte PkmGetLegalityResultIdentifier(long handle, int index)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return 0;
        var results = new LegalityAnalysis(pk).Results;
        return (uint)index < (uint)results.Count ? (byte)results[index].Identifier : (byte)0;
    }

    /// <summary>
    /// Human-readable message for the legality result at the given index (e.g. "Invalid: Ball is
    /// not a valid Ball for encounter."), fully resolved (item/species/move names substituted in,
    /// not a raw template) via the same LegalityLocalizationContext.Humanize PKHeX.Core itself uses
    /// to build pkhex_pkm_get_legality_report's text.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legality_result_message")]
    public static unsafe int PkmGetLegalityResultMessage(long handle, int index, char* outBuffer, int outBufferLength)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return -1;
        var la = new LegalityAnalysis(pk);
        if ((uint)index >= (uint)la.Results.Count)
            return 0;
        var localizer = LegalityLocalizationContext.Create(la);
        var message = localizer.Humanize(la.Results[index]);
        if (outBuffer is null || outBufferLength < message.Length)
            return message.Length;
        message.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return message.Length;
    }

    /// <summary>
    /// Applies a curated, mechanically-safe quick-fix for the legality result at the given index,
    /// if one is available for its category. There is no general-purpose "make this Pokemon legal"
    /// engine in PKHeX.Core (that's a separate closed-source tool, AutoLegalityMod, not part of
    /// this library) — this only handles a small set of common, unambiguous repairs:
    ///   Trainer  -> resets OT name/gender/TID/SID/language to the given save's own trainer.
    ///   Memory   -> clears OT+HT memories (PKM.ClearMemories()).
    ///   Handler  -> sets CurrentHandler to 0 (OT) if HandlingTrainerName is empty, else 1 (HT) —
    ///               matches whichever state is actually consistent with the stored HT name.
    ///   Ball     -> resets to Poké Ball (the one Ball valid for every encounter type/generation).
    /// Returns 1 if a fix was applied, 0 if this category has no available quick-fix (caller should
    /// leave the issue for manual editing), -1 if the handle(s) are invalid.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_apply_legality_fix")]
    public static int PkmApplyLegalityFix(long pkmHandle, long saveHandle, int index)
    {
        if (HandleTable.Get<PKM>(pkmHandle) is not { } pk)
            return -1;
        var la = new LegalityAnalysis(pk);
        if ((uint)index >= (uint)la.Results.Count)
            return -1;
        var identifier = la.Results[index].Identifier;
        switch (identifier)
        {
            case CheckIdentifier.Trainer:
                if (HandleTable.Get<SaveFile>(saveHandle) is not { } sav)
                    return -1;
                pk.OriginalTrainerName = sav.OT;
                pk.OriginalTrainerGender = sav.Gender;
                pk.TID16 = sav.TID16;
                pk.SID16 = sav.SID16;
                pk.Language = sav.Language;
                return 1;
            case CheckIdentifier.Memory:
                pk.ClearMemories();
                return 1;
            case CheckIdentifier.Handler:
                pk.CurrentHandler = string.IsNullOrEmpty(pk.HandlingTrainerName) ? (byte)0 : (byte)1;
                return 1;
            case CheckIdentifier.Ball:
                pk.Ball = 4; // Poké Ball: valid regardless of encounter/generation.
                return 1;
            default:
                return 0;
        }
    }

    /// <summary>
    /// Programmatic name of a CheckIdentifier ordinal (e.g. "Trainer", "Memory", "Ball",
    /// "Handler") — matches the enum member name exactly, not a display string. Lets callers
    /// switch on category by name instead of hardcoding ordinal numbers that would silently break
    /// if PKHeX.Core reorders the enum. Empty string for an out-of-range value.
    /// Returns the required length in chars; call once with null to size, again to fill.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_check_identifier_get_name")]
    public static unsafe int CheckIdentifierGetName(byte identifier, char* outBuffer, int outBufferLength)
    {
        var name = Enum.IsDefined(typeof(CheckIdentifier), identifier) ? ((CheckIdentifier)identifier).ToString() : "";
        if (outBuffer is null || outBufferLength < name.Length)
            return name.Length;
        name.AsSpan().CopyTo(new Span<char>(outBuffer, outBufferLength));
        return name.Length;
    }

    /// <summary>
    /// Highest move ID valid for this PKM's format, for building a fallback "all moves" picker.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_max_move_id")]
    public static ushort PkmGetMaxMoveId(long handle) => HandleTable.Get<PKM>(handle)?.MaxMoveID ?? 0;

    /// <summary>
    /// Highest item ID valid for this PKM's format, for building a held-item picker (e.g.
    /// 1...maxItemID, same shape as species/move pickers).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_max_item_id")]
    public static ushort PkmGetMaxItemId(long handle) => (ushort)(HandleTable.Get<PKM>(handle)?.MaxItemID ?? 0);

    /// <summary>
    /// Number of move IDs this PKM can currently legally learn (level-up, egg, TM/tutor, and the
    /// moves from its recorded encounter/relearn set), for building a move picker. Move ID 0
    /// ("None") is never included; callers should add their own placeholder for clearing a slot.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legal_move_count")]
    public static int PkmGetLegalMoveCount(long handle)
    {
        var moves = GetLegalMoves(handle);
        return moves?.Count ?? -1;
    }

    /// <summary>
    /// The move ID at the given index into this PKM's legal-move list (see
    /// pkhex_pkm_get_legal_move_count).
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_legal_move")]
    public static ushort PkmGetLegalMove(long handle, int moveListIndex)
    {
        var moves = GetLegalMoves(handle);
        if (moves is null || moveListIndex < 0 || moveListIndex >= moves.Count)
            return 0;
        return moves[moveListIndex];
    }

    private static List<ushort>? GetLegalMoves(long handle)
    {
        if (HandleTable.Get<PKM>(handle) is not { } pk)
            return null;
        try
        {
            var la = new LegalityAnalysis(pk);
            var info = new LegalMoveInfo();
            info.ReloadMoves(la);
            var result = new List<ushort>();
            for (ushort move = 1; move <= pk.MaxMoveID; move++)
            {
                if (info.CanLearn(move))
                    result.Add(move);
            }
            return result;
        }
        catch
        {
            return [];
        }
    }
}
