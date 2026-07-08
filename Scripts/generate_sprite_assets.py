#!/usr/bin/env python3
"""
Generates an Xcode asset catalog (Sprites.xcassets) from PKHeX.Drawing.PokeSprite's bundled
Pokemon sprite PNGs. Each PNG becomes a single-scale .imageset named after its file stem
(e.g. "b_25-1s"), matching the file names produced by PKHeX.Native's
pkhex_pkm_get_sprite_file_name export.

Run this again whenever vendor/PKHeX's sprite PNGs change (e.g. after a submodule update).
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIRS = [
    ROOT / "vendor/PKHeX/PKHeX.Drawing.PokeSprite/Resources/img/Big Pokemon Sprites",
    ROOT / "vendor/PKHeX/PKHeX.Drawing.PokeSprite/Resources/img/Big Shiny Sprites",
]
DEST = ROOT / "PKHeXMac/Resources/Assets.xcassets/Sprites"

IMAGESET_CONTENTS = {
    "images": [{"filename": None, "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1},
}


def main() -> None:
    if DEST.exists():
        shutil.rmtree(DEST)
    DEST.mkdir(parents=True)

    count = 0
    for source_dir in SOURCE_DIRS:
        for png in sorted(source_dir.glob("*.png")):
            imageset_dir = DEST / f"{png.stem}.imageset"
            imageset_dir.mkdir()
            shutil.copy2(png, imageset_dir / png.name)
            contents = json.loads(json.dumps(IMAGESET_CONTENTS))
            contents["images"][0]["filename"] = png.name
            (imageset_dir / "Contents.json").write_text(json.dumps(contents, indent=2))
            count += 1

    (DEST / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2))
    print(f"Generated {count} imagesets in {DEST}")


if __name__ == "__main__":
    main()
