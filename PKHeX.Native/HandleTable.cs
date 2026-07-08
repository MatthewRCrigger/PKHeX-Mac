using System;
using System.Collections.Concurrent;
using System.Threading;

namespace PKHeX.Native;

/// <summary>
/// Tracks managed objects (SaveFile, PKM) exposed to native callers as opaque integer handles,
/// since object references cannot cross the NativeAOT/C ABI boundary.
/// </summary>
internal static class HandleTable
{
    private static readonly ConcurrentDictionary<long, object> Handles = new();
    private static long _next;

    public static long Add(object obj)
    {
        ArgumentNullException.ThrowIfNull(obj);
        var id = Interlocked.Increment(ref _next);
        Handles[id] = obj;
        return id;
    }

    public static T? Get<T>(long handle) where T : class => Handles.TryGetValue(handle, out var obj) ? obj as T : null;

    public static bool Remove(long handle) => Handles.TryRemove(handle, out _);
}
