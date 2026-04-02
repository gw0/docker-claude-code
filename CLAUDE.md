# CLAUDE.md

- Respect `.gitignore` and skip files and dirs prefixed with "_".
- Use the `codemap` skill when exploring the codebase.

## Commands

**Note:** `docker` commands cannot be run directly — ask the user to run them.

```bash
# Format and lint all code (shfmt, shellcheck, dockerfmt, yamlfmt, markdownlint-cli2)
make fmt

# Build the Docker image (ask user to run)
make build
```

CI enforces formatting: `lint.yaml` runs `make fmt` inside the image and fails if `git diff` shows changes. Always run `make fmt` before committing.

## Architecture

This project is a containerized Claude Code sandbox. The two primary artifacts are:

1. **`claude-aliases.bashrc`** — Shell integration that creates per-profile aliases (`cc1`, `cc1-yolo`, `cc1-advisor`). Each alias calls `_claude_run` which spins up `docker run -it --rm` with: profile-specific state volume (`~/.claude-<profile>`), current directory mounted, all capabilities dropped, no-new-privileges, and host networking.

2. **`Dockerfile`** — Six-stage build:
   - **DEB Packages**: System packages (git, gh, jq, ripgrep, docker-ce-cli, etc.)
   - **Claude Tools**: `claude-code`, `claude-powerline`, `agentshield`, `git-delta` via Bun
   - **Lint/Format Tools**: `dockerfmt`, `shfmt`, `shellcheck`, `yamlfmt`, `markdownlint-cli2`
   - **User Setup**: Creates non-root `agent` user (UID 1000)
   - **Claude Plugins**: SuperClaude, claude-skills, codemap, and 33+ antigravity-awesome-skills bundles installed as local plugin marketplace
   - **Shell Interface**: Bash customization, aliases, readline config

3. **`scripts/entrypoint.sh`** — Container init chain: maps arbitrary UID/GID via NSS wrapper → initializes `~/.claude` → sets up audit log → symlinks shared config from image → enables plugins (default: `sc codemap`) → runs security scans (AgentShield + unicode detection) → execs `claude` with all arguments.

4. **`claude-shared/`** — Shared config copied into the image:
   - `managed-settings.d/00-defaults.json`: Default Claude settings (plan mode, sonnet model, tool allow/deny lists, audit-logging hooks)
   - `agents/advisor.md`: Read-only advisory agent (WebFetch/WebSearch only)
   - `claude-powerline.json`: Prompt theme with cost/context display

### Permission Model

`managed-settings.d/00-defaults.json` enforces plan mode by default with a tool allowlist (date, ls, mkdir, git status/log/diff/add/commit, etc.) and denylist (rm -rf, sudo, piped curl|bash, ssh, chmod 777). This file is symlinked at runtime via entrypoint.

### Plugin System

Plugins are installed during Docker build into `/claude-shared/plugins-marketplaces/local/` and exposed as a local Claude Code marketplace. At startup, entrypoint enables plugins listed in `ENABLE_PLUGINS` (default: `sc codemap`). `scripts/install-aas-bundles.py` parses `bundles.md` from antigravity-awesome-skills and generates per-bundle plugin directories + `plugin.json` metadata files.

### Dependency Updates

`renovate.json` uses custom regex managers to track versions pinned in Dockerfile comments and groups all updates into a single PR. `@anthropic-ai/claude-code` has 0-day minimum release age for instant updates.
