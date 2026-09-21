# PKHeXMac

A native macOS save editor for the Pokémon core series, built on
[PKHeX](https://github.com/kwsch/PKHeX)'s save-parsing and legality engine.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-lightgrey.svg)
![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-black.svg)
![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)

PKHeX is a Windows/WinForms application. On a Mac it runs under Wine or a VM, with
the rough edges that implies. PKHeXMac keeps the part of PKHeX that is genuinely hard
— the save format handling and legality checking in `PKHeX.Core` — and replaces the
interface with a SwiftUI app that behaves like a Mac app: real windows, ⌘O/⌘S,
Finder integration, drag and drop between windows.

`PKHeX.Core` is consumed as an **unmodified upstream submodule**, compiled to a native
dylib with .NET NativeAOT and called directly from Swift. There is no Wine, no Mono,
no .NET runtime to install, and no fork of PKHeX to keep in sync — updating to a newer
PKHeX is a submodule bump.

> [!IMPORTANT]
> This is an unofficial, independent project. It is not affiliated with or endorsed by
> the PKHeX authors, Nintendo, Game Freak, or The Pokémon Company.
>
> **Editing save files carries risk.** Keep your own backups. On the first write to a save
> in a session PKHeXMac copies the original alongside it as `.bak` (unless one already
> exists, or you turn it off in Settings) — that is a safety net, not a backup strategy.
>
> **Do not use hacked Pokémon in battle or in trades with people who are unaware of it.**
> This project does not support or condone cheating at the expense of others.

## Features

**Storage**
- Browse and edit every box plus the party, with a pinned party strip
- Per-window saves — open several games at once, each in its own window
- Drag and drop Pokémon between boxes, between party and boxes, and **between windows**,
  converting across generations on drop (the destination save decides the format)
- Copy/paste (⌘C/⌘V) within a save; multi-select and bulk release within a box
- Click an empty slot to add a species from a searchable picker, starting from a legal
  blank template stamped with the save's own trainer

**Pokémon editor**
- Summary: species, nickname, level, nature, ball, gender, shininess, held item, status
- Stats: IVs and EVs with live totals
- Moves: move picker restricted to the legal learnset, with PP
- Met: met location and date, egg location and date, met level, fateful encounter, egg state
- Trainer: OT name/gender/ID/SID/friendship, Handling Trainer, and OT/HT memories
- Ability picker with flavor-text descriptions
- Live **legality check** with per-issue severity, and one-click fixes for issues PKHeX
  knows how to repair

**Trainer and bag**
- Trainer identity (name, gender, TID/SID), money, play time, Pokédex seen/caught
- Bag editor across every pouch, with an item picker limited to items legal for that pouch
  (including the legacy Gen 1–3 item numbering)

**App**
- Multi-window, Finder "Open With" for save files, unsaved-change tracking
- Themeable accent color

Supported games and formats are whatever the pinned `PKHeX.Core` supports — currently
Generations 1 through 9, including `main`, `*.sav`, `*.dsv`, `*.dat`, `*.gci` and friends.

## Status

This is a working app that is not finished. Known gaps:

- **Apple Silicon only.** The NativeAOT dylib is published for `osx-arm64`; there is no
  Intel or universal build.
- **No code signing or notarization.** There are no prebuilt releases — build it yourself.
- Settings has **Appearance** built; *Editing*, *Files & Backups*, *Shortcuts* and *About*
  are placeholders. Within Appearance, only the accent color and "back up save before
  writing" are wired to behavior — the other toggles persist but do nothing yet.
- Not covered: Mystery Gift, Pokédex editing, Showdown import/export, QR codes, battle
  videos, GameCube memory cards, and the other extras PKHeX proper offers.
- No automated tests.

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0 or later, Apple Silicon |
| Xcode | 16 or later (Swift 6) |
| [.NET SDK](https://dotnet.microsoft.com/download) | 10.0 or later, installed at `~/.dotnet` |
| [XcodeGen](https://github.com/yonaskolb/XcodeGen) | `brew install xcodegen` |

The Xcode project's pre-build script invokes `dotnet` from `~/.dotnet` with a scrubbed
environment (`/usr/bin/env -i`), so the SDK must be at that path — the Microsoft installer
script's default. Adjust the `PATH` in [`project.yml`](project.yml) if yours lives elsewhere.

## Building

```bash
git clone --recurse-submodules https://github.com/MatthewRCrigger/PKHeX-Mac.git
cd PKHeX-Mac
xcodegen generate
open PKHeXMac.xcodeproj
```

Already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

The PKHeX submodule carries upstream's full history, so expect the clone to pull a few
hundred MB.

Build and run the `PKHeXMac` scheme. The first build is slow: it runs a NativeAOT publish of
`PKHeX.Interop` (which compiles all of `PKHeX.Core` ahead of time) before Xcode compiles any
Swift.

To build a Release copy and install it into `/Applications`:

```bash
Scripts/install_app.sh
```

That script also re-signs the bundle as a unit — copying the `.app` out of DerivedData without
re-signing leaves the outer binary and the embedded framework with mismatched ad-hoc team IDs,
and dyld refuses to load it.

## How it works

```
  SwiftUI views              PKHeXMac/Sources/PKHeXSwiftUI
        │
        ▼
  Swift wrapper types        PKHeXMac/Sources/PKHeXCore        SaveFile, PKM, Bag
        │                                                      (PKHeXCore.framework)
        ▼
  C module map               PKHeXMac/Sources/CPKHeXNative     pkhex_native.h
        │
        ▼  C ABI
  NativeAOT dylib            PKHeX.Interop                     [UnmanagedCallersOnly] exports
        │
        ▼
  PKHeX.Core                 vendor/PKHeX (submodule)          unmodified upstream
```

Managed object references can't cross the C ABI, so `PKHeX.Interop` hands out opaque `int64`
handles from a [`HandleTable`](PKHeX.Interop/HandleTable.cs) and the Swift layer wraps them in
types that own their lifetime. Strings cross as UTF-16 buffers with a caller-supplied length,
which `NativeString.swift` reduces to ordinary Swift `String`s.

Everything upstream lacks is added **beside** the submodule rather than inside it. Ability
flavor text, for example, isn't in `PKHeX.Core` at all; PKHeXMac embeds its own resource in
`PKHeX.Interop` and loads it through the `Util.GetStringList` extension point `PKHeX.Core`
already exposes. That keeps `vendor/PKHeX` a clean checkout that can be fast-forwarded.

### Repository layout

| Path | Contains |
|---|---|
| `PKHeXMac/Sources/PKHeXSwiftUI/` | The app: views, stores, theming |
| `PKHeXMac/Sources/PKHeXCore/` | Swift wrappers over the C ABI |
| `PKHeXMac/Sources/CPKHeXNative/` | C header and module map |
| `PKHeXMac/Resources/Assets.xcassets/` | Generated sprite, artwork, item and ball catalogs |
| `PKHeX.Interop/` | C# NativeAOT bridge over `PKHeX.Core` |
| `Scripts/` | Asset generators and the install script |
| `vendor/PKHeX/` | Upstream PKHeX, as a submodule |
| `project.yml` | XcodeGen project definition — **edit this, not the `.xcodeproj`** |

`PKHeXMac.xcodeproj` is generated. Run `xcodegen generate` after changing `project.yml`;
hand-edits to the project or to `Info.plist` are dropped on the next generate.

### Updating PKHeX

```bash
git -C vendor/PKHeX fetch --tags
git -C vendor/PKHeX checkout <tag>
python3 Scripts/generate_sprite_assets.py     # if the sprite PNGs changed
python3 Scripts/generate_artwork_assets.py    # if the artwork/item/ball PNGs changed
git add vendor/PKHeX PKHeXMac/Resources/Assets.xcassets
```

Then rebuild — NativeAOT recompiles `PKHeX.Core` from the new checkout. Watch for compile
errors in `PKHeX.Interop`: it calls `PKHeX.Core` APIs directly, and upstream refactors them
freely between releases.

## License

GPL-3.0. See [LICENSE](LICENSE).

PKHeXMac links `PKHeX.Core` into its binary and redistributes PKHeX's sprite and artwork
resources, so it is a derivative work of PKHeX and is licensed under the same terms.

PKHeX is copyright © Kaphotics ([@kwsch](https://github.com/kwsch)) and contributors,
licensed under GPL-3.0.

Pokémon and all related names and imagery are trademarks of Nintendo, Creatures Inc., and
Game Freak Inc. This project is a fan-made tool with no affiliation to any of them.
