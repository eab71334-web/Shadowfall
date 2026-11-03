# Shadowfall - project notes for Claude Code

Mobile game made with **Godot 4.3 (GDScript)**. The owner writes Arabic: reply to him in Arabic, keep answers short
(he reads on a phone and has no computer; everything is built by GitHub Actions: APK + unsigned IPA).

## Layout
- `project.godot`, `export_presets.cfg`, `scenes/main.tscn`
- `scripts/main.gd`      menus, shop, LAN screens, screen flow
- `scripts/game.gd`      autoload `Game`: save data, weapons for the campaign, translations (TR dict), sounds
- `scripts/net.gd`       autoload `Net`: LAN (ENet + UDP discovery), lobby config, up to 4 players, bots
- `scripts/battle.gd`    campaign / co-op waves (host authoritative)
- `scripts/arena.gd`     **Stick Fight style PvP arena** (22 weapons, block/parry, throw, ragdolls, hazards, bots, LAN)
- `scripts/stickman.gd`  procedural stick figure rig + animation (thin colored style for the arena)
- `scripts/weapon_art.gd`, `ragdoll.gd`, `effects.gd`, `backdrop.gd`, `touch_controls.gd`, `ui_kit.gd`
- `.github/workflows/build.yml` builds APK/IPA and records test videos (preview, arena, LAN) as artifacts.

## Goal
The owner wants the arena to feel exactly like "Stick Fight: The Game" (single player vs bots and LAN 2-4 players):
loose flailing characters, dynamic camera, weapon crates from the sky, pick up / throw / spinning pickups,
and physics-based maps (stacked crates and planks that collapse when shot) - the collapsing maps are NOT done yet.

## Rules that avoid build errors (Godot 4.3)
- Indent with TABS. Never use `:=` when the value comes from an untyped Variant (dictionary lookups, `e.prop` on untyped vars): declare the type explicitly.
- Keep RPC function signatures identical on every peer; node names `Battle` / `Arena` must stay unique.
- The sandbox cannot run Godot: validate by reading the CI logs and the test videos uploaded as artifacts.
- UI must fit 1280x600 (landscape phone); action buttons live in a fixed bottom bar.

## Arena controls (twin stick)
Left floating stick: walk, push up = jump (spins when moving), push down = crouch. Right floating stick: aim 360 deg (hand/weapon follows), push to the edge = fire/hit. Buttons: block (parry window 0.22s) and throw weapon (thrown along the aim, spinning, 55 dmg).
