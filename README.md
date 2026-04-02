# claude-cage - Claude Code Container Sandbox

Run Claude Code in an isolated Docker container with per-profile state, security hardening, a set of pre-installed plugins and skills, and support for remote dev environments. A single shell alias is all it takes.

- **Security isolation**: AI agent sandbox via non-root user, all capabilities dropped, startup security scans (AgentShield + unicode), audit log at `~/.claude/audit-log.jsonl`
- **Multi-profile support**: Per-profile auth state and history in `~/.claude-<profile>`, separate work and personal accounts, mix subscription and API key billing
- **Plugins and skills**: SuperClaude, claude-skills, codemap, and 33+ antigravity-awesome-skills bundles pre-installed
- **Remote dev support**: Mutagen bidirectional sync + Docker socket forwarding for remote execution
- **Minimal by design**: A shell alias script and a Dockerfile, no dependencies beyond Docker, easy to read and modify
- **Pass-through CLI**: All extra arguments forwarded directly to `claude`

## Build

```bash
docker build -t claude-cage .
# or pull latest:
docker pull ghcr.io/gw0/claude-cage:main
```

## Install

For shell integration update `~/.bashrc` (provide profile names, replace `/path/to`):

```bash
echo "CLAUDE_PROFILES='cc1 ccpersonal claudeapi'" >> ~/.bashrc
echo "source /path/to/claude-aliases.bashrc" >> ~/.bashrc

source ~/.bashrc
```

## Usage

Each profile gets three alias modes:

- `<profile>` — standard interactive mode
- `<profile>-yolo` — skips tool approval prompts (`--allow-dangerously-skip-permissions`)
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
  -v ${HOME}/.claude-cc1:/home/agent/.claude \
  -v ${PWD}:/workspace/$(basename ${PWD}):rslave \
  -w /workspace/$(basename ${PWD}) \
  ghcr.io/gw0/claude-cage:main claude
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

- `ANTHROPIC_API_KEY` — Anthropic API key passed into the container, can override a subscription profile with API key billing
- `CLAUDE_IMAGE` — Docker image to use (default: `ghcr.io/gw0/claude-cage:main`)
- `CLAUDE_PROFILES` — Space-separated profile names for alias generation (default: `cc1 cc2 ccapi`)
- `ENABLE_PLUGINS` — Space-separated plugin names to enable at startup (default: `sc codemap`)
- `FORCE_RESET_SESSIONS` — Set to `1` to wipe sessions/cache on container start
- `SKIP_SECURITY_SCAN` — Set to `1` to skip AgentShield and unicode scans
- `DOCKER_HOST` — Docker socket URL, e.g. for remote dev environments

## Remote dev environment

Claude runs locally, edits files in the local workspace, but executes commands in the remote dev environment via Docker socket forwarding.

1. Local: Claude container runs locally, edits files in workspace, has access to local port (set as `DOCKER_HOST`)
2. Mutagen: Syncs workspace files bidirectionally (`local workspace <-> remote workspace`)
3. Mutagen: Forwards local connections to remote restricted Docker socket (`local port -> remote dev-docker-proxy`)
4. Remote: Restrict that only EXEC commands get to remote Docker socket (`remote dev-docker-proxy -> remote Docker socket`)
5. Remote: Claude executes docker exec commands that run in remote dev-container (`docker exec -> ... -> dev-container`)

Install dependencies:

```bash
curl -Lo mutagen.tar.gz https://github.com/mutagen-io/mutagen/releases/download/v0.18.1/mutagen_linux_amd64_v0.18.1.tar.gz
tar -xzf mutagen.tar.gz -C ~/bin
```

In your project dir set up a containerized dev environment similar to `remote-example/`.

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
# with shell integration
cd ~/my-project
DOCKER_HOST=tcp://127.0.0.1:2375 cc1
```

## License

Copyright &copy; 2025-2026 *gw0* [<http://gw.tnode.com/>] &lt;<gw.2026@ena.one>&gt;

All code is licensed under the GNU Affero General Public License 3.0+ (`AGPL-3.0-or-later`). All modifications and complete source code must be made publicly available to any user.
