# Makefile Review Findings — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four bugs found in Makefile code review: broken `shell-local` exec, `migrate-claude` matching the wrong container, macOS symlink breaking the container label filter, and migrated files landing with wrong ownership.

**Architecture:** All fixes are in `Makefile`. No new files. Two tasks: one for `shell-local`, one for the `migrate-claude` recipe (three related fixes batched together since they all touch the same shell script block).

**Tech Stack:** GNU Make, POSIX shell, Docker CLI

---

## Files

| File | Change |
|------|--------|
| `Makefile` | Fix line 55 (`shell-local` exec); replace `migrate-claude` recipe (lines 63–83) |

---

### Task 1: Fix `shell-local` — remove `--config` from `devcontainer exec`

**Problem:** `devcontainer exec` does not accept `--config`. The flag is valid for `up`/`down` but not `exec`. `shell-local` currently passes it, which causes the exec step to fail after `up-local` succeeds. Compare line 52 (`shell`) which correctly omits it.

**Files:**
- Modify: `Makefile:55`

- [ ] **Step 1: Verify the current broken command**

```bash
make -n shell-local 2>&1 | grep exec
```

Expected output (the `--config` flag is present — this is the bug):
```
devcontainer exec --workspace-folder /Users/tim/workspace/devcontainer --config /Users/tim/workspace/devcontainer/.devcontainer/devcontainer.local.json -- /bin/zsh
```

- [ ] **Step 2: Apply the fix**

In `Makefile`, change line 55 from:
```makefile
	$(CLI) exec --workspace-folder $(WORKSPACE) $(CONFIG_FLAG) -- /bin/zsh
```
to:
```makefile
	$(CLI) exec --workspace-folder $(WORKSPACE) -- /bin/zsh
```

- [ ] **Step 3: Verify the fix**

```bash
make -n shell-local 2>&1 | grep exec
```

Expected output (`--config` is gone, matches `shell` on line 52):
```
devcontainer exec --workspace-folder /Users/tim/workspace/devcontainer -- /bin/zsh
```

Also verify `shell` (the non-local variant) is still unchanged:
```bash
make -n shell 2>&1 | grep exec
```

Expected:
```
devcontainer exec --workspace-folder /Users/tim/workspace/devcontainer -- /bin/zsh
```

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "fix: remove --config from devcontainer exec in shell-local"
```

---

### Task 2: Fix `migrate-claude` — path canonicalization, container selection, and file ownership

**Three bugs addressed together (all in the same recipe block):**

1. **Symlink** (`line 65`): On macOS, `$PWD` can return `/var/...` while the devcontainer label stores `/private/var/...`. The `docker ps` label filter does an exact match and misses the container. Fix: resolve the real path with `cd && pwd -P` before the filter.

2. **Wrong container** (`line 65`): When both the default volume-backed container and the `-local` bind-mount container exist for the same workspace, `head -1` may pick the bind-mount one. That container has no named volume, so `VOLUME` is empty and migration fails. Fix: iterate all matching containers and find the one with a named volume at `/home/vscode/.claude`.

3. **Ownership** (`line 82`): `docker run alpine` runs as root. `cp -a` preserves source ownership (uid 1000/vscode). Files land on the host owned by uid 1000, not the host user, making them unreadable by Claude Code. Fix: after copying, `chown -R` to the host uid/gid inside the same Alpine invocation.

**Files:**
- Modify: `Makefile:63–83`

- [ ] **Step 1: Verify current behavior (dry run)**

```bash
make -n migrate-claude 2>&1
```

Note the current `docker ps` filter line and `docker run` line — these are what we're replacing.

- [ ] **Step 2: Replace the migrate-claude recipe**

Replace lines 63–83 in `Makefile` with the following. **Preserve the exact tab indentation** on recipe lines (Makefile requires tabs, not spaces).

```makefile
migrate-claude: ## Copy ~/.claude from the devcontainer Docker volume to host ~/.claude
	@REAL_WORKSPACE=$$(cd -- "$(WORKSPACE)" 2>/dev/null && pwd -P || echo "$(WORKSPACE)"); \
	CONTAINER=""; VOLUME=""; \
	for C in $$(docker ps -a \
	  --filter "label=devcontainer.local_folder=$$REAL_WORKSPACE" \
	  --format "{{.ID}}"); do \
	  V=$$(docker inspect "$$C" \
	    --format '{{range .Mounts}}{{if and (eq .Destination "/home/vscode/.claude") (eq .Type "volume")}}{{.Name}}{{end}}{{end}}'); \
	  if [ -n "$$V" ]; then \
	    CONTAINER="$$C"; VOLUME="$$V"; break; \
	  fi; \
	done; \
	if [ -z "$$CONTAINER" ]; then \
	  echo "ERROR: No volume-backed devcontainer found for $$REAL_WORKSPACE. Start it once with the default targets first."; \
	  exit 1; \
	fi; \
	HOST_UID=$$(id -u); HOST_GID=$$(id -g); \
	echo "Copying from Docker volume $$VOLUME to $(HOME)/.claude ..."; \
	mkdir -p $(HOME)/.claude; \
	docker run --rm \
	  -v "$$VOLUME:/src" \
	  -v "$(HOME)/.claude:/dst" \
	  alpine sh -c "cp -a /src/. /dst/ && chown -R $$HOST_UID:$$HOST_GID /dst/"; \
	echo "Done. You can now use 'make shell-local'."
```

- [ ] **Step 3: Verify the fix — path canonicalization**

```bash
make -n migrate-claude 2>&1 | head -5
```

Expected: the first shell line sets `REAL_WORKSPACE` using `cd && pwd -P`.

- [ ] **Step 4: Verify the fix — container loop replaces head -1**

```bash
grep -n 'head -1' Makefile
```

Expected: no output (the `head -1` is gone).

```bash
grep -n 'for C in' Makefile
```

Expected: a line showing the loop iterating container IDs.

- [ ] **Step 5: Verify the fix — chown present after cp**

```bash
grep -n 'chown' Makefile
```

Expected output showing the chown inside the alpine sh -c invocation:
```
82:	  alpine sh -c "cp -a /src/. /dst/ && chown -R $$HOST_UID:$$HOST_GID /dst/"; \
```

(Line number may differ by a line or two depending on exact placement.)

- [ ] **Step 6: Verify the fix — type=volume filter present**

```bash
grep -n 'eq .Type' Makefile
```

Expected:
```
    --format '{{range .Mounts}}{{if and (eq .Destination "/home/vscode/.claude") (eq .Type "volume")}}{{.Name}}{{end}}{{end}}'); \
```

This ensures only named volumes (not bind mounts) match — the core fix for the wrong-container selection bug.

- [ ] **Step 7: Commit**

```bash
git add Makefile
git commit -m "fix: migrate-claude — canonicalize path, select volume-backed container, fix ownership"
```
