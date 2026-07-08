using System;
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
}
