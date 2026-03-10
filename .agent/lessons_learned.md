# Lessons Learned

This document tracks known anti-patterns and specific fixes that arose during the development of this project. AI Agents should review these lessons to avoid introducing previously resolved bugs, especially regarding engine-specific quirks or CI/CD pipeline constraints.

## 1. GDScript Circular Dependencies in Headless CI
**Context:** When running Godot tests via `addons/gut/gut_cmdln.gd` in a headless CI environment (like GitHub Actions), Godot compiles GDScript files from scratch rather than relying on a warm editor cache.

**Anti-Pattern:** Using `.new()` on a globally registered `class_name` where a circular reference may exist.
*Example:* `GameManager` references `Ship`, and `Ship` references `GameManager`. Using `Ship.new()` inside `GameManager.gd` will cause headless Godot to treat `Ship` as an unvalidated raw generic Object instead of the custom class, leading to a `"Invalid call. Nonexistent function 'new' in base 'GDScriptNativeClass'."` crash during CI tests.

**Required Fix (Lazy Loading):**
Always explicitly `load()` the script path when instantiating it inside another heavily-coupled class to ensure the script parses completely during headless loading.

```gdscript
# BAD (Causes CI Crashes due to circular class_name loading):
var new_ship = Ship.new()

# GOOD (Forces parsing via explicit load path):
var new_ship = load("res://Scripts/Ship.gd").new()
```

## 2. Godot 4 Headless Image Asset Importing
**Context:** When running Godot 4 in a headless CI environment to execute tests, it won't always automatically import `.png` files into the compressed `.ctex` files stored in `.godot/imported/` just by using the `--editor` flag, leading to "Unable to open file" test crashes.

**Anti-Pattern:** Assuming `godot --headless --editor --quit-after X` builds the full asset cache for CI.

**Required Fix (Dummy Packager):**
Use the Godot export packager flag with a discard destination `/dev/null` for your target CI platform. This explicitly forces the engine's resource pipeline to hash, compress, and cache all project assets before tests begin.

*Example CI Pipeline Step:*
```yaml
- name: Import Assets
  run: ./godot --path . --headless --export-pack "Linux" /dev/null || true
```

## 3. SceneTree Node Parenting in Headless Tests
**Context:** Godot expects visual objects (like `Node2D` Sprites) to exist within the active `SceneTree` to properly calculate values like `Z-Index` or `global_position`.

**Anti-Pattern:** Instantiating a visual node in a Gut test and appending it directly to a logic array without also adding it to the engine's SceneTree.

*Example:* `_game_manager.ships.append(Ship.new())`
This causes C++ level engine crashes (`Condition "p_child->data.parent != this" is true`) during headless test execution when code later attempts to sort those nodes or modify their transforms because Godot throws null-pointer exceptions when finding orphaned Node2Ds.

**Required Fix (Add Child):**
Always ensure visual test objects are passed to `add_child()` on an active tree node.

```gdscript
var test_ship = load("res://Scripts/Ship.gd").new()
_game_manager.add_child(test_ship) # <--- CRITICAL FOR HEADLESS C++ ENGINE STABILITY
_game_manager.ships.append(test_ship)
```

## 4. Asynchronous Phase Transitions and RPC Re-entrancy
**Context:** When a Godot client (`ComputerOpponent` or Player) issues an RPC to transition the game state (e.g., `request_execute_movement`), network interactions inherently run asynchronously. High-latency connections or internal `await` statements (like yielding for visual animations or mine detonations) on the server cause delays before the new phase state propagates back to clients.

**Anti-Pattern:** Allowing clients to repeatedly evaluate the same phase state during `await` yielding, leading to multiple identical phase transition RPC spams. Simultaneously, allowing the Server's transition handler (`execute_all_movement`) to execute concurrently without re-entrancy protections lead to severe multi-threaded race conditions (e.g., arrays mutating out of bounds or global RNG seed sync loss) when those duplicate RPCs hit.

**Required Fix (Boolean Guards & Re-entrancy Flags):**
1. Implement a local waiting state flag (`_is_waiting_for_transition = true`) on the Client that bypasses redundant logic until the Server officially broadcasts the new phase.
2. Implement a global execution lock (`_is_executing_movement = true`) at the top of the Server's transition handler to drop concurrent RPC execution threads and release the lock only when transitioning is fully resolved.
