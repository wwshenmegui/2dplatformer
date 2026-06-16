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
- `Shift` — dash (only active when the player's `dash_enabled` is on)
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

## Roles

### Game Tester

The Game Tester role is responsible for validating gameplay by running the project and exercising its systems interactively.

**How to run the game**

Use the `godot:run_project` tool, passing the path to the project directory. To test a specific scene in isolation (e.g. a single level), pass the scene path via the optional `scene` parameter. Stop the session with `godot:stop_project` when done.

**What to test**

Only test what you changed. Identify which scenes or scripts were modified in this task, then test only those. Do not run a full regression pass unless explicitly asked.

*Scoping rules:*
- Changed a level scene or a script that a level uses (e.g. `level.gd`, `enemy.gd`, `collectible.gd`) → test that level.
- Changed a player script (`player.gd`, `inventory.gd`) or a shared element → test any one level that exercises that system.
- Changed the menu (`menu.tscn` / `menu.gd`) → test the menu only.

*Navigating to a level via the menu:*
1. Run the project with `godot:run_project` (no `scene` parameter so it starts from `scenes/menu.tscn`).
2. Use the `computer` tool to click the **Select Level** button in the menu.
3. Click the level that corresponds to the scene you changed.
4. Play through it to verify your change behaves correctly.

Alternatively, if you need to isolate a scene quickly, pass its path directly via the `scene` parameter of `godot:run_project` (e.g. `scenes/level_2.tscn`).

*Per-system checklist — apply only the items relevant to what changed:*
- **Movement** — walk left/right (`A`/`D`), jump (`Space`), dash (`Shift`; only works when `dash_enabled` is on)
- **Combat** — attack (`J`), verify enemy takes damage and the player's invincibility window triggers correctly
- **Collectibles & Coins** — press `E` near a collectible to pick it up; walk into coins for auto-collection; confirm both update the HUD/inventory as expected
- **Inventory** — open/close with `I`; use items with `E`; verify heal items restore HP
- **Win/Lose conditions** — reach the exit on a final level (win screen); fall into a deathzone or lose all HP (lose screen)
- **Pause** — press `Escape`; confirm it is blocked while the backpack is open
- **Physics layer integrity** — enemies, player, terrain, and collectibles should collide/ignore each other per the layer assignments in the Architecture section

**What to report**

For each issue found, note: the scene tested, the steps to reproduce, the expected behaviour, and the actual behaviour. Reference the relevant script (e.g. `scripts/player/player.gd`) where applicable.

---

### UI

- `BackpackUI` uses `process_mode = PROCESS_MODE_ALWAYS` so it remains interactive while the tree is paused
- `HpHud`, `PauseMenu`, `WinScreen`, `LoseScreen` are children of `UILayer` inside the level scene
