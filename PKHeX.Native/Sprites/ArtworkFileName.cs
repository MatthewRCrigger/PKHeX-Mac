using System;
using System.Text;
using PKHeX.Core;
using static PKHeX.Core.Species;

namespace PKHeX.Native.Sprites;

/// <summary>
/// Filename generator for vendor/PKHeX/PKHeX.Drawing.PokeSprite/Resources/img/Artwork Pokemon
/// Sprites (and its Artwork Shiny Sprites counterpart) — a separate, newer icon set than "Big
/// Pokemon Sprites" (see SpriteFileName.cs) that covers species up through National Dex #1025,
/// versus Big Pokemon Sprites' cutoff around #905. Prefer this set once the app needs to display
/// Pokemon beyond Gen 8.
///
/// Follows the same species/form/gender/formarg suffix conventions as SpriteFileName, with one
/// confirmed difference: no Gen 6 Pikachu cosplay ('c') suffix — the artwork set has one icon per
/// Pikachu form, without a separate costume variant (verified: zero "a_25-*c.png" files exist on
/// disk). Coverage of every other form/shiny suffix combination has NOT been exhaustively
/// diffed against the shipped file list (in particular Gigantamax forms, and shiny variants,
/// appear sparser than the base set) — callers must fall back to progressively simpler filenames
/// (strip shiny, then strip form, then bare species) when the exact generated name isn't present
/// in the shipped asset catalog, rather than assuming this generator's output always exists.
/// </summary>
public static class ArtworkFileName
{
    private const char GGStarter = 'p';

    /// <summary>
    /// Gets the base file name (without extension) of the Pokémon artwork, e.g. "a_1025",
    /// "a_25-1" (no cosplay 'c' suffix, unlike the small-sprite set). Best-effort: see class
    /// remarks on falling back when the exact file isn't shipped.
    /// </summary>
    public static string GetArtworkFileName(ushort species, byte form, byte gender, uint formarg, EntityContext context, bool shiny)
    {
        if (SpriteFileName.SpeciesDefaultFormSprite.Contains(species))
            form = 0;

        if (species == (ushort)Xerneas && context == EntityContext.Gen9a)
            form = 1;

        var sb = new StringBuilder(16);
        sb.Append("a_").Append(species);

        if (form != 0)
        {
            sb.Append('-').Append(form);

            if (species == (ushort)Eevee && form == 1)
                sb.Append(GGStarter);
            else if (species == (ushort)Pikachu && form == 8)
                sb.Append(GGStarter);
        }

        if (gender == 1 && SpriteFileName.SpeciesGenderedSprite.Contains(species))
            sb.Append('f');

        if (species == (ushort)Alcremie)
        {
            if (form == 0)
                sb.Append('-').Append(form);
            sb.Append('-').Append(formarg);
        }

        if (shiny)
            sb.Append('s');

        return sb.ToString();
    }
}
