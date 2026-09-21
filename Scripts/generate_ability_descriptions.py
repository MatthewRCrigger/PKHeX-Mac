#!/usr/bin/env python3
"""
Generates PKHeX.Interop/Resources/text_AbilityDescriptions_en.txt — same line-per-ability-ID layout
as PKHeX.Core's own text_Abilities_en.txt (line N = ability ID N, including the line-1 placeholder
for ID 0/None), but holding each ability's short flavor-text description instead of its name.
PKHeX.Core ships no ability descriptions at all. Rather than patching the submodule to add one, the
file is embedded in PKHeX.Interop and read back through the extension point PKHeX.Core exposes for
exactly this purpose — Util.GetStringList(name, EmbeddedResourceCache) over our own assembly; see
PkmExports.AbilityDescriptions. That keeps vendor/PKHeX an unmodified upstream checkout.

Source data: Examples/abilities-table.html (git-ignored; a saved copy of a Pokemon reference site's
sortable abilities table — one <tr> per ability with Name/Pokemon-count/Description/Gen columns).
That table only has one row per unique name (308 rows for 309 real ability slots, since PKHeX's own
list repeats "As One" and "Embody Aspect" across multiple IDs for Calyrex/Ogerpon forms) and doesn't
cover every name PKHeX has (a handful of very new/placeholder entries have no description available
yet) — IDs with no matching row are written as an empty line, and are treated as "no description
available" by the picker UI (falls back to hiding the description) rather than a hard error.

Run this again whenever Examples/abilities-table.html is refreshed with a newer ability list.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE_HTML = ROOT / "Examples/abilities-table.html"
NAMES_FILE = ROOT / "vendor/PKHeX/PKHeX.Core/Resources/text/other/en/text_Abilities_en.txt"
OUT_FILE = ROOT / "PKHeX.Interop/Resources/text_AbilityDescriptions_en.txt"

ROW_RE = re.compile(
    r'<tr>\s*<td>\s*<a class="ent-name"[^>]*>([^<]*)</a>\s*</td>.*?'
    r'<td class="cell-med-text">([^<]*)</td>',
    re.S,
)


def normalize_name(name: str) -> str:
    # The source HTML uses a straight apostrophe; PKHeX.Core's own ability names use a curly one
    # (e.g. "Mind’s Eye", "Dragon’s Maw") — normalize so lookups by PKHeX name succeed.
    return name.strip().replace("'", "’")


def main() -> None:
    if not SOURCE_HTML.exists():
        raise SystemExit(
            f"{SOURCE_HTML} not found — this is a git-ignored file the user saves locally "
            "from a Pokemon reference site's abilities table; re-save it before running this script."
        )

    html = SOURCE_HTML.read_text(encoding="utf-8")
    rows = ROW_RE.findall(html)
    # Descriptions that wrap across source lines carry embedded "\n      " indentation — collapse
    # all internal whitespace runs to a single space so each description is exactly one line.
    descriptions = {
        normalize_name(name): re.sub(r"\s+", " ", desc).strip() for name, desc in rows
    }

    names = NAMES_FILE.read_text(encoding="utf-8").splitlines()
    out_lines = []
    missing = []
    for i, name in enumerate(names):
        if i == 0:
            out_lines.append("")  # ID 0 ("—"/None) has no ability, matching text_Abilities_en.txt.
            continue
        desc = descriptions.get(name, "")
        if not desc:
            missing.append(name)
        out_lines.append(desc)

    OUT_FILE.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    print(f"Wrote {len(out_lines)} lines to {OUT_FILE}")
    if missing:
        print(f"{len(missing)} abilities with no description found (left blank): {missing}")


if __name__ == "__main__":
    main()
