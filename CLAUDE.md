# CLAUDE.md

- Make sure the result is simple, lean, and consistent, as if written from scratch.
- Respect `.gitignore` and skip files and dirs prefixed with "_".
- Use the `codemap` skill when exploring the codebase.

## Commands

**Note:** `docker` commands cannot be run directly — ask the user to run them.

```bash
# Format and lint all code (shfmt, shellcheck, dockerfmt, ruff, yamlfmt, markdownlint-cli2)
make fmt

# Build image (ask user to run)
make build

# Smoke test (ask user to run)
make test
```

CI enforces formatting: `lint.yaml` runs `make fmt` inside the image and fails if `git diff` shows changes. Always run `make fmt` before committing.

## Architecture

This project is a containerized Claude Code sandbox. The two primary artifacts are:

1. **`claude-aliases.bashrc`** — Shell integration that creates one alias per profile/account for each mode/variant. Each alias calls `_claude_run` which spins up `docker run -it --rm` with: profile-specific state volume (`~/.claude-<profile>`), current directory mounted, all capabilities dropped, no-new-privileges, host networking, and an auto-detected gVisor (runsc) runtime when registered with the host Docker daemon.

2. **`Dockerfile`** — Build on `debian:trixie-slim`, one RUN per section ordered from least to most frequently changed:
   - **Base system**: System packages (git, gh, jq, ripgrep, docker-ce-cli, etc.) and Bun as JS runtime (`bunx`, `node` alias)
   - **User and shell**: Non-root user (`USER`/`USER_UID`/`USER_GID`, default `agent`/1000), bash/readline/vim customization, home symlinks into `~/.claude`
   - **Lint/fmt tools**: `dockerfmt`, `shfmt`, `shellcheck`, `yamlfmt`, `ruff`, `markdownlint-cli2`
   - **Claude tools**: `claude-powerline`, `agentshield`, `git-delta`
   - **Claude plugins**: codemap, `rtk` (CLI + hook), SuperClaude, claude-skills, and agentic-awesome-skills bundles installed as local plugin marketplace
   - **Claude Code**: `claude-code` via Bun (most frequently bumped)
   - **Managed settings and workarounds**: `scripts/entrypoint.sh`, `claude-shared/` (root-owned, read-only), and bwrap shim via `dpkg-divert`
   - BuildKit mounts: `type=cache` for apt/bun/pip caches, `type=tmpfs` on `/tmp` for download scratch, `type=bind` for build-only scripts

3. **`scripts/entrypoint.sh`** — Container init chain: maps arbitrary UID/GID via NSS wrapper → initializes `~/.claude` → sets up audit log → symlinks shared config from image → enables plugins (default: `sc codemap`) → runs security scans (AgentShield + unicode detection) → execs `claude` with all arguments.

4. **`claude-shared/`** — Shared config copied into the image:
   - `managed-settings.d/10-core.json`: Model, UI prefs, env vars
   - `managed-settings.d/10-permissions.json`: Tool allow/deny lists and default plan mode
   - `managed-settings.d/10-hooks-audit-log.json`: Audit-logging hooks (SessionStart, PreToolUse, ConfigChange → `~/.claude/audit-log.jsonl`)
   - `managed-settings.d/20-hooks-rtk.json`: RTK token compression hook (disable via `DISABLE_RTK=1`)
   - `agents/advisor.md`: Read-only advisory agent (WebFetch/WebSearch only)
   - `claude-powerline.json`: Prompt theme with cost/context display

### Permission Model

`managed-settings.d/10-permissions.json` enforces plan mode by default with a tool allowlist (date, ls, mkdir, git status/log/diff/add/commit, etc.) and denylist (rm -rf, sudo, piped curl|bash, ssh, chmod 777). These files are symlinked at runtime via entrypoint.

### Plugin System

Plugins are installed during Docker build into `~/.claude-shared/plugins-marketplaces/local/` and exposed as a local Claude Code marketplace. At startup, entrypoint enables plugins listed in `ENABLE_PLUGINS` (default: `sc codemap`). `scripts/install-aas-bundles.py` parses `bundles.md` from agentic-awesome-skills and generates per-bundle plugin directories + `plugin.json` metadata files.

### Dependency Updates

`renovate.json` uses custom regex managers to track versions pinned in Dockerfile comments and groups all updates into a single PR. `@anthropic-ai/claude-code` has 0-day minimum release age for instant updates.
