using System;
using System.Text;
using PKHeX.Core;
using static PKHeX.Core.Species;

namespace PKHeX.Interop.Sprites;

/// <summary>
/// Ported from PKHeX.Drawing.PokeSprite.SpriteName.GetResourceStringSprite, which cannot be
/// referenced directly because PKHeX.Drawing.PokeSprite depends on System.Drawing.Common
/// (Windows-only, incompatible with a portable NativeAOT bridge). Keep in sync with upstream's
/// vendor/PKHeX/PKHeX.Drawing.PokeSprite/Util/SpriteName.cs if that logic changes.
///
/// Unlike the original (which returns a resx member-name key using '_' as every separator),
/// this returns the on-disk PNG filename directly: the species/form separator is '-' on disk
/// (e.g. "b_25-1s.png"), matching vendor/PKHeX/PKHeX.Drawing.PokeSprite/Resources/img/Big Pokemon Sprites.
/// </summary>
public static class SpriteFileName
{
    private const char Cosplay = 'c';
    private const char Shiny = 's';
    private const char GGStarter = 'p';

    /// <summary>
    /// Gets the base file name (without extension) of the Pokémon sprite, e.g. "b_25", "b_100-1s".
    /// </summary>
    public static string GetSpriteFileName(ushort species, byte form, byte gender, uint formarg, EntityContext context, bool shiny)
    {
        if (SpeciesDefaultFormSprite.Contains(species))
            form = 0;

        if (species == (ushort)Xerneas && context == EntityContext.Gen9a)
            form = 1;

        var sb = new StringBuilder(16);
        sb.Append("b_").Append(species);

        if (form != 0)
        {
            sb.Append('-').Append(form);

            if (species == (ushort)Pikachu)
            {
                if (context == EntityContext.Gen6)
                    sb.Append(Cosplay);
                else if (form == 8)
                    sb.Append(GGStarter);
            }
            else if (species == (ushort)Eevee)
            {
                if (form == 1)
                    sb.Append(GGStarter);
            }
        }

        if (gender == 1 && SpeciesGenderedSprite.Contains(species))
            sb.Append('f');

        if (species == (ushort)Alcremie)
        {
            if (form == 0)
                sb.Append('-').Append(form);
            sb.Append('-').Append(formarg);
        }

        if (shiny)
            sb.Append(Shiny);

        return sb.ToString();
    }

    /// <summary>Species whose sprite art doesn't vary by form (only the default/form-0 art
    /// exists). Shared with ArtworkFileName, which follows the same rule.</summary>
    internal static ReadOnlySpan<ushort> SpeciesDefaultFormSprite =>
    [
        (ushort)Mothim,
        (ushort)Scatterbug,
        (ushort)Spewpa,
        (ushort)Rockruff,
        (ushort)Mimikyu,
        (ushort)Sinistea,
        (ushort)Polteageist,
        (ushort)Urshifu,
        (ushort)Dudunsparce,
        (ushort)Poltchageist,
        (ushort)Sinistcha,
    ];

    /// <summary>Species with a distinct female sprite (suffixed 'f' on disk). Shared with
    /// ArtworkFileName, which follows the same rule.</summary>
    internal static ReadOnlySpan<ushort> SpeciesGenderedSprite =>
    [
        (ushort)Hippopotas,
        (ushort)Hippowdon,
        (ushort)Unfezant,
        (ushort)Frillish,
        (ushort)Jellicent,
        (ushort)Pyroar,
    ];
}
