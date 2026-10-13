---
name: sync-game-repo
description: >-
  Exports all active scripts and modules from Roblox Studio (ServerScriptService, ReplicatedStorage, StarterPlayer, StarterGui, ReplicatedFirst, ServerStorage) into the local workspace (src/), checks git diffs, commits the updates, and pushes them to the GitHub repository (kevinS766/Zero). Use this skill whenever the user asks to export the game, sync Roblox Studio to GitHub, update the repository, or backup code changes to git.
---

# Sync Game Repo (Roblox Studio -> GitHub)

This skill automates the extraction of all Luau scripts directly from a running Roblox Studio session to the local `src/` directory and synchronizes the changes with the remote GitHub repository (`kevinS766/Zero`).

---

## Workflow Steps

### Step 1: Ensure Sync Server is Running
A local HTTP listener (`tools/sync_server.py`) receives files exported from Studio over port 34567.

1. Test if the server is already active:
   ```bash
   curl -s http://127.0.0.1:34567
   ```
2. If not running, launch it in the background:
   ```powershell
   bash -c "python tools/sync_server.py"
   ```
   *(Run as a background daemon process).*

### Step 2: Trigger Studio Export via Luau
Execute the export payload inside Roblox Studio using `execute_luau`:

1. Get the current Studio instance ID using `list_roblox_studios`.
2. Call `execute_luau` with:
   - `datamodel_type`: `"Edit"`
   - `studio_id`: Active Studio ID
   - `code`: The contents of [export_payload.luau](./scripts/export_payload.luau)
3. Verify the output reports scripts exported across all services:
   ```text
   Export finished. Total: 120 (ServerScriptService: 30, ReplicatedStorage: 36, StarterPlayer: 43, ...)
   ```

### Step 3: Verify Local Disk Changes
Check that the scripts were written to the `src/` directory:
```bash
git status -s
```

### Step 4: Commit and Push to GitHub
Run the sync script or execute the git commands:

1. Run the helper script with a descriptive commit message:
   ```bash
   bash .agents/skills/sync-game-repo/scripts/git_push.sh "feat: sync game scripts from Roblox Studio"
   ```
   *(Or pass a custom message if specific features were implemented).*

2. Verify that `git status` reports:
   ```text
   Your branch is up to date with 'origin/main'.
   nothing to commit, working tree clean
   ```

---

## Validation Checklist
- [ ] `http://127.0.0.1:34567` returned `{"status":"ready"}`.
- [ ] Roblox Studio `execute_luau` returned without errors.
- [ ] Files in `src/` reflect latest updates.
- [ ] `git push origin main` succeeded with code 0.
