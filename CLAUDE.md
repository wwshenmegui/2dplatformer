# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A 2D platformer built with **Godot 4.4** and **GDScript**. Run and edit the project through the Godot editor — there is no build command or CLI test runner.

## Running the Game

Open the project in Godot 4.4 and press **F5** to run from the main scene (`scenes/menu.tscn`), or **F6** to run the currently open scene. There are no automated tests.

## Input Actions

Defined in `project.godot`:
- `A` / `D` — move left/right
- `Space` — jump
- `J` — attack
- `E` — interact (collect item, use item in inventory)
- `I` — open/close inventory (backpack)
- `Escape` — pause

## Physics Layers

Layer assignments (important when adding new collision shapes):
1. `level` — terrain/platforms
2. `player`
3. `deathzone`
4. `exit`
5. `enemy`
6. `collectibles`
7. `player_attack`
8. `coins`

## Architecture

### Scene / Script pairing

Every scene has a paired script in `scripts/` mirroring the `scenes/` folder structure.

### Level orchestration (`scripts/level.gd`)

`level.gd` is the central coordinator. On `_ready` it:
- Connects `player.player_died` → shows lose screen + pauses
- Connects each enemy's `damage_player` signal
- Connects `deathzone.entered_deathzone` → `reset_player()`
- Connects `exit.exit_reached` → win screen (only if `is_final_level = true`)
- Connects all `Coins` group nodes' `coin_collected` signals
- Connects all `Collectibles` group nodes' `collected` signals
- Wires the `BackpackUI` with the player's inventory

Pause/inventory state is mutually exclusive: ESC is blocked while the backpack is open, and the backpack pauses the tree when visible.

### Player (`scripts/player/player.gd`)

- `CharacterBody2D` with exported `speed`, `gravity`, `jumpforce`, `max_hp`
- Owns an `Inventory` resource instance; connects its `item_used` signal to apply effects (e.g. `"heal"`)
- Invincibility uses `await get_tree().create_timer()` — no separate timer node
- HUD is reached by hardcoded path `/root/Level/UILayer/HpHud`; keep that node path stable

### Inventory (`scripts/player/inventory.gd`)

- Extends `Resource` (not Node), so it can be passed by reference
- Item registry lives in `item_properties` dict inside the script — add new item types there
- Signals: `inventory_changed`, `item_used(item_id)`

### Enemy (`scripts/elements/enemy.gd`)

Patrols left/right using an `EdgeCheck` RayCast2D to detect ledges and reverses on wall collision. Uses an `Area2D` child to detect player contact and calls `player.take_damage(damage, global_position)` directly.

### Collectibles vs Coins

- **Collectibles** (`collectible.gd`) — require `E` to pick up; emit `collected(item_id)` → `player.collect_item(item_id)` → `inventory.add_item()`
- **Coins** (`coin.gd`) — auto-collected on contact; emit `coin_collected(value)` → `player.collect_coins(value)`; tracked separately from inventory on the player (`player.coins`)

### UI

- `BackpackUI` uses `process_mode = PROCESS_MODE_ALWAYS` so it remains interactive while the tree is paused
- `HpHud`, `PauseMenu`, `WinScreen`, `LoseScreen` are children of `UILayer` inside the level scene
