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
