# docker-claude-code - Dockerized Claude Code Sandbox

Run **Claude Code in an isolated Docker container** with multi-profile support, security hardening, best-practice defaults, a set of pre-installed skills and remote dev support. A simple shell alias is all it takes.

- **Drop-in replacement**: Works exactly like `claude` — same arguments, same workflow, just run `cc1` instead of `claude`.
- **Secure sandbox**: Non-root user, all capabilities dropped, hardened seccomp profile, startup security scans (AgentShield + unicode), audit log at `~/.claude/audit-log.jsonl`.
- **Multi-profile support**: Per-profile persistent state in `~/.claude-<profile>` to separate work and personal accounts, mix subscription and API key billing.
- **Best practices by default**: Start in plan mode, optimized token usage, telemetry disabled, claude-powerline status line, pre-configured tool allowlist and denylist.
- **Plugins and skills**: SuperClaude, claude-skills, codemap, and 33+ antigravity-awesome-skills bundles pre-installed, enabled on demand via `/plugin`.
- **Remote dev support**: Mutagen bidirectional sync + Docker socket forwarding allow executing commands in a remote dev environment.
- **Minimal and auditable**: ~200 lines of shell + Dockerfile, no dependencies beyond Docker, small enough to read and modify — don't trust us, ask your AI to audit it.

## Build

```bash
docker build -t docker-claude-code .
# or pull latest:
docker pull ghcr.io/gw0/docker-claude-code:main
```

## Install

Download the shell alias script and hardened seccomp, customize your profile names (`CLAUDE_PROFILES`), and source it in `~/.bashrc`:

```bash
mkdir -p ~/.config/docker-claude-code
curl -fsSLo ~/.config/docker-claude-code/claude-aliases.bashrc https://raw.githubusercontent.com/gw0/docker-claude-code/main/claude-aliases.bashrc
curl -fsSLo ~/.config/docker-claude-code/claude-seccomp.json https://raw.githubusercontent.com/gw0/docker-claude-code/main/claude-seccomp.json

echo 'export CLAUDE_PROFILES="cc1 ccpersonal claudeapi"' >> ~/.bashrc
echo 'source ~/.config/docker-claude-code/claude-aliases.bashrc' >> ~/.bashrc
source ~/.bashrc
```

## Usage

Each profile gets three alias modes:

- `<profile>` — standard interactive mode
- `<profile>-yolo` — skips tool approval prompts (`--dangerously-skip-permissions`)
- `<profile>-advisor` — read-only advisory mode, no file writes (`--agent advisor`)

All extra arguments pass through to `claude` directly (e.g. `-p "prompt"`, `--model`).

```bash
# run interactive mode:
cd ~/my-project
cc1

# or advisor/no-file-access mode:
ccpersonal-advisor

# or yolo/dangerously-skip-permissions mode with prompt:
ccapi-yolo -p "Please review latest changes and fix issues"

# or manually (expert):
cd ~/my-project
docker run -it --rm \
  -v "${HOME}/.claude-cc1:/home/agent/.claude" \
  -v "${PWD}:${PWD}" \
  -w "${PWD}" \
  ghcr.io/gw0/docker-claude-code:main claude
```

## Plugins and skills

Plugins and skills come pre-installed in the image and managed via Claude Code's native plugin system (use `/plugin` and `/reload-plugins` to enable them on-demand, resets on restart).

| Plugin | Source | Content |
| ------ | ------ | ------- |
| `sc` | [SuperClaude Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework) | 39 commands, 25 agents, 1 skill |
| `cs` | [claude-skills](https://github.com/Jeffallan/claude-skills) | ~5 commands, 90 skills |
| `codemap` | [codemap](https://github.com/AZidan/codemap) | 1 skill (structural codebase indexing, 60-80% token reduction) |
| `aas-full` | [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) | all 1,273+ skills |
| `aas-essentials` | antigravity | 5 skills |
| `aas-security-engineer` | antigravity | 7 skills |
| `aas-security-developer` | antigravity | 6 skills |
| `aas-web-wizard` | antigravity | 7 skills |
| `aas-web-designer` | antigravity | 6 skills |
| `aas-full-stack-developer` | antigravity | 6 skills |
| `aas-agent-architect` | antigravity | 6 skills |
| `aas-llm-application-developer` | antigravity | 5 skills |
| `aas-indie-game-dev` | antigravity | 6 skills |
| `aas-python-pro` | antigravity | 7 skills |
| `aas-typescript-javascript` | antigravity | 5 skills |
| `aas-systems-programming` | antigravity | 5 skills |
| `aas-startup-founder` | antigravity | 6 skills |
| `aas-business-analyst` | antigravity | 5 skills |
| `aas-marketing-growth` | antigravity | 6 skills |
| `aas-devops-cloud` | antigravity | 7 skills |
| `aas-observability-monitoring` | antigravity | 6 skills |
| `aas-data-analytics` | antigravity | 6 skills |
| `aas-data-engineering` | antigravity | 5 skills |
| `aas-creative-director` | antigravity | 6 skills |
| `aas-qa-testing` | antigravity | 7 skills |
| `aas-mobile-developer` | antigravity | 5 skills |
| `aas-integration-apis` | antigravity | 5 skills |
| `aas-architecture-design` | antigravity | 5 skills |
| `aas-ddd-evented-architecture` | antigravity | 8 skills |
| `aas-oss-maintainer` | antigravity | 7 skills |
| `aas-skill-author` | antigravity | 6 skills |

Enable plugins at startup with the `ENABLE_PLUGINS` env var (default: `sc codemap`):

```bash
ENABLE_PLUGINS="aas-essentials aas-web-wizard" cc1
```

## Env variables

- `ANTHROPIC_API_KEY` — Use Anthropic API key billing, can temporarily override a subscription profile
- `CLAUDE_IMAGE` — Docker image to use (default: `ghcr.io/gw0/docker-claude-code:main`)
- `CLAUDE_PROFILES` — Space-separated profile names for alias generation (default: `cc1 cc2 ccapi`)
- `ENABLE_PLUGINS` — Space-separated plugin names to enable at startup (default: `sc codemap`)
- `FORCE_RESET_SESSIONS` — Set to `1` to wipe sessions/cache on container start
- `DISABLE_SECURITY_SCAN` — Set to `1` to skip [AgentShield](https://github.com/affaan-m/agentshield) and unicode scans
- `DISABLE_RTK` — Set to `1` to disable [RTK](https://github.com/rtk-ai/rtk) token compression
- `DOCKER_EXTRA_ARGS` — Extra arguments passed to `docker run` (e.g. `-e DOCKER_HOST=tcp://127.0.0.1:2375 --net host` for remote dev environment)

## Git/GitHub integration

Create a separate GitHub bot user with classic PAT. First-time setup (run via `docker exec -it ...` or use "!" prefix inside Claude):

```bash
# Git-only integration:
git config --global user.name "Your Bot"
git config --global user.email "you-bot@users.noreply.github.com"

# Git/GitHub integration:
echo "YOUR_BOT_GITHUB_PAT" | gh auth login --with-token
gh auth setup-git
git config --global user.name "$(gh api user --jq '.name // .login')"
git config --global user.email "$(gh api user --jq '.email // "\(.login)@users.noreply.github.com"')"
git config --global author.name "Your Name"
git config --global author.email "you@users.noreply.github.com"
```

Git config and GitHub CLI auth persist in the per-profile persistent dir.

## Remote dev environment

Claude runs locally, edits files in the local workspace, but executes commands in the remote dev environment via Docker socket forwarding.

1. Local: Claude container runs locally, edits files in workspace, has access to forwarded local port
2. Mutagen: Syncs workspace files bidirectionally (`local workspace <-> remote workspace`)
3. Mutagen: Forwards local connections to remote restricted Docker socket (`local port -> remote dev-docker-proxy`)
4. Remote: Restrict so that only EXEC commands get to remote Docker socket (`remote dev-docker-proxy -> remote Docker socket`)
5. Remote: Claude executes docker exec commands that run in remote dev-container (`docker exec -> ... -> dev-container`)

Install dependencies:

```bash
curl -Lo mutagen.tar.gz https://github.com/mutagen-io/mutagen/releases/download/v0.18.1/mutagen_linux_amd64_v0.18.1.tar.gz
tar -xzf mutagen.tar.gz -C ~/bin
```

In your project dir, set up a containerized dev environment similar to `remote-example/`.

Start and manage a remote dev environment (via SSH):

```bash
cd ~/my-project
DOCKER_HOST=ssh://user@remote mutagen project start
mutagen project list

# management:
mutagen project resume
mutagen project terminate
```

Run local Claude with remote execution:

```bash
# with shell integration:
cd ~/my-project
DOCKER_EXTRA_ARGS="-e DOCKER_HOST=tcp://127.0.0.1:2375 --net host" cc1
```

## License

Copyright &copy; 2025-2026 *gw0* [<http://gw.tnode.com/>] &lt;<gw.2026@ena.one>&gt;

All code is licensed under the GNU Affero General Public License 3.0+ (`AGPL-3.0-or-later`). All modifications and complete source code must be made publicly available to any user.
