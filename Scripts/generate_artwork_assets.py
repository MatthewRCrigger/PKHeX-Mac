#!/usr/bin/env python3
"""
Generates Xcode asset catalogs from PKHeX.Drawing.PokeSprite's bundled artwork PNGs — a separate,
newer icon set than the one generate_sprite_assets.py ships (see that script's docstring), covering:

  - Pokemon artwork (species up through National Dex #1025, vs. the older set's ~#905 cutoff),
    matching pkhex_pkm_get_artwork_file_name.
  - Item icons ("Big Items", the set PKHeX.Core's own SpriteUtil.GetItemSprite defaults to),
    keyed by internal item ID (e.g. "bitem_425"), plus the bitem_unk/bitem_tm/bitem_tr fallback
    icons PKHeX itself uses for items with no dedicated art.
  - Poke Ball icons, keyed by the Ball enum's raw byte value (e.g. "_ball4" = Poke Ball).

Each PNG becomes a single-scale .imageset named after its file stem, same convention as
generate_sprite_assets.py. Run this again whenever vendor/PKHeX's art PNGs change.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
IMG = ROOT / "vendor/PKHeX/PKHeX.Drawing.PokeSprite/Resources/img"

# (source dir, dest catalog name, glob pattern)
SETS = [
    (IMG / "Artwork Pokemon Sprites", "Artwork", "*.png"),
    (IMG / "Artwork Shiny Sprites", "Artwork", "*.png"),
    (IMG / "Big Items", "ItemIcons", "*.png"),
    (IMG / "ball", "BallIcons", "*.png"),
    (IMG / "Status", "StatusIcons", "*.png"),
]

IMAGESET_CONTENTS = {
    "images": [{"filename": None, "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1},
}


def generate_catalog(dest: Path, sources: list[tuple[Path, str]]) -> int:
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)

    count = 0
    for source_dir, pattern in sources:
        for png in sorted(source_dir.glob(pattern)):
            imageset_dir = dest / f"{png.stem}.imageset"
            imageset_dir.mkdir()
            shutil.copy2(png, imageset_dir / png.name)
            contents = json.loads(json.dumps(IMAGESET_CONTENTS))
            contents["images"][0]["filename"] = png.name
            (imageset_dir / "Contents.json").write_text(json.dumps(contents, indent=2))
            count += 1

    (dest / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    return count


def main() -> None:
    by_name: dict[str, list[tuple[Path, str]]] = {}
    for source_dir, name, pattern in SETS:
        by_name.setdefault(name, []).append((source_dir, pattern))

    assets_root = ROOT / "PKHeXMac/Resources/Assets.xcassets"
    for name, sources in by_name.items():
        dest = assets_root / name
        count = generate_catalog(dest, sources)
        print(f"Generated {count} imagesets in {dest}")


if __name__ == "__main__":
    main()
