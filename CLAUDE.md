# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Hold the Line** — Godot 4.6, 2D isometric auto-battle / card placement game (Orcs Must Die style). Player drags character cards onto the battlefield during a prep phase; characters then auto-fight enemy waves infinitely. Single scene: `scenes/battle.tscn`.

- Viewport: 480×270, Mobile renderer, pixel art (nearest filter), canvas_items stretch
- TileMap: isometric, tile_shape=1, tile_size=16×8, TileSet source **id=3** (not 0)
- Font: `fonts/m3x6.ttf`
- Autoload: `MapManager` (`scripts/map_manager.gd`)

## Running the Game

Open the project in **Godot 4.6** and press F5 (or the Play button). There is no CLI build — all running, testing, and editing is done inside the Godot editor.

## Architecture

### Game Loop (battle.gd)
`battle.gd` is the central controller on `scenes/battle.tscn`:
1. `_ready` → loads a random map, loads card pool, connects Hand signals, deals cards, spawns wave enemies (frozen).
2. Player drags cards → `hand.gd` emits `character_spawn_requested` → `spawn_player_character()` (frozen=true during prep).
3. When hand reaches ≤2 cards, `hand.gd` emits `fight_requested` → `start_wave()` unfreezes everyone.
4. When all enemies die → `_wave_won()`: apply stat bonuses, load new map, redistribute surviving players to random player-zone tiles, deal 3 new cards, spawn next wave.

### Two-Phase Combat (frozen flag)
Characters have a `frozen: bool`. During prep phase all spawned units are frozen — `character.gd._process()` returns early when frozen. `start_wave()` clears frozen on all groups.

### Card System
- `CardData` (Resource): rarity, card_type (WARRIOR/PASSIVE), character_data ref, weight for drop rate.
- `CharacterData` (Resource): texture (spritesheet), has_attack_anim, stats (max_hp, atk, def, spd, move_speed), rarity.
- Cards live in `Hand` (HBoxContainer). On drag, the card is reparented to the `DragLayer` Control node (group: `"ui_layer"`) inside the CanvasLayer so it renders above everything. On drop it reparents back.
- `static var any_dragging` on `card.gd` prevents multi-card drag.
- Dragging is blocked when `hand.battle_active == true`.

### Spritesheet Convention
- **12-frame** chars (`has_attack_anim = true`): frames 0–3 attack, 4–7 walk, 8–11 death.
- **8-frame** chars (`has_attack_anim = false`): frames 0–3 walk, 4–7 death.
- `character.gd._build_frames()` creates SpriteFrames programmatically from these slices.
- Chars with `has_attack_anim = false`: **char_3, char_7, char_10**.

### Map System
- Maps live in `scenes/maps/` as `.tscn` files, each containing a `TileMapLayer` node.
- `MapManager` (autoload) scans the folder at startup, picks a random map avoiding repeat.
- Player zone = left half (`cell.x <= _map_mid_x`). Enemy zone = right half. Midpoint computed from min/max x of used cells.
- **Do NOT call `get_cell_tile_data()` to check player_zone in `_get_player_zone_tiles()`** — the TileSet source id is 3, not 0, and it crashes. Use `cell.x <= _map_mid_x` only.
- Player-zone tile placement in `card.gd._get_hovered_tile()` uses `player_zone` custom data (TYPE_BOOL) on tiles; this is set per-map in the editor.

### Wave & Scaling
- `WaveGenerator` loads enemy CharacterData from `assets/enemy_data/`, picks by rarity weight (BRONZE 100 → DIAMOND 15), scales stats by `1.0 + wave * 0.1`, applies `enemy_bonuses` multipliers.
- `WaveData` (Resource): wave_number, enemies array, spawn_interval.
- Per-wave bonus: one random stat for player, a different random stat for enemy, each boosted by `wave * 1%`. Bonuses compound multiplicatively. Displayed via animated `BonusLabel`.

### Scene Node Requirements (battle.tscn)
Key nodes the script expects:
- `$MapContainer` (Node2D) — map instances added here
- `$Characters` (Node2D) — character instances added here
- `$UI/Hand` — must have group `"hand_node"`
- `$UI/WaveLabel` (Label)
- `$UI/BonusLabel` (Label) — starts visible=false, centered, large font
- Inside UI CanvasLayer: `DragLayer` (Control) with group `"ui_layer"`

### Asset Directories
- `assets/card_data/` — CardData .tres files (card_1 … card_20)
- `assets/character_data/` — player CharacterData .tres files (char_1_data … char_20_data)
- `assets/enemy_data/` — enemy CharacterData .tres files (same naming, separate instances)
- `assets/` — card frame PNGs: bronze_card, silver_card, gold_card, emerald_card, diamond_card

### Known Gotchas
- `queue_free()` is deferred — always read `get_child_count() - 1` BEFORE calling it when deciding whether to trigger fight.
- After a new map loads, call `hand.update_tilemap(_tilemap)` so existing cards get the new TileMapLayer reference.
- Always wrap scene-tree node accesses with `is_instance_valid()` — characters call `queue_free()` after death animation and can be freed mid-frame.
- `_apply_bonuses_to_players()` applies the *incremental* portion of the bonus only (divides out the previous multiplier) — do not refactor to a simple multiply or stats will compound incorrectly.
