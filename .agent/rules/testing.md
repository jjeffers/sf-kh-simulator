---
trigger: always_on
---

# Rule: Godot Test Verification
**Trigger:** Any change to `.gd` files or `.tscn` files.
**Action:**
1. After any modification, the agent MUST run the Godot test suite in headless mode.
2. **Command:** `godot --headless --path . -s addons/gut/gut_cmdline.gd` (or your specific test runner command).
3. The agent MUST parse the output. If "FAILED" is present in the results, the agent MUST immediately revert the change or fix the logic.
4. If the agent creates a *new* test file, it must add that file to the relevant test suite configuration before running.

**Invariants:**
- Never commit code that breaks the existing ship combat mechanics.
- If a test requires a specific scene (like `combat_manager.tscn`), ensure the scene is properly instanced in the test script.