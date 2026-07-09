using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using PKHeX.Core;

namespace PKHeX.Native;

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
    /// Highest move ID valid for this PKM's format, for building a fallback "all moves" picker.
    /// </summary>
    [UnmanagedCallersOnly(EntryPoint = "pkhex_pkm_get_max_move_id")]
    public static ushort PkmGetMaxMoveId(long handle) => HandleTable.Get<PKM>(handle)?.MaxMoveID ?? 0;

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
