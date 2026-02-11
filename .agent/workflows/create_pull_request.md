---
description: Create a Pull Request (PR) for code changes
---

1.  **Check out a new branch**:
    -   Use `git checkout -b <branch_name>`.
    -   Name the branch descriptively (e.g., `feature/add-new-ship`, `bugfix/fix-freeze`).

2.  **Make your changes**:
    -   Edit the code as needed.
    -   Ensure tests pass (if applicable).

3.  **Stage and Commit**:
    -   Use `git add .` to stage all changes.
    -   Use `git commit -m "<message>"` with a clear message describing the update.

4.  **Push the branch to remote**:
    // turbo
    -   Run: `git push -u origin HEAD`

5.  **Create the Pull Request**:
    -   If `gh` CLI is installed: `gh pr create --fill`
    -   Otherwise, visit the repository URL provided in the push output (e.g., `https://github.com/.../pull/new/<branch_name>`).

6.  **Switch back to main (once merged)**:
    -   `git checkout main`
    -   `git pull`
