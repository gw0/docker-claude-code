# Containerized Claude Code and AI agents

Docker environment for running Claude Code with isolated AI agents and SuperClaude integration.

## Build

```bash
docker build -t claude .
# or pull latest:
docker pull ghcr.io/gw0/docker-claude-code:main
```

## Install

For shell integration update `~/.bashrc` (provide profile names, replace `/path/to`):

```bash
echo "CLAUDE_PROFILES='claude1 claude2 claudeapi'" >> ~/.bashrc
echo "source /path/to/claude-aliases.bashrc" >> ~/.bashrc

source ~/.bashrc
```

## Usage

```bash
# with shell integration
cd ~/my-project
claude1

# or advisor/no-file-access mode:
claude2-advisor

# or yolo/dangerously-skip-permissions mode with prompt:
claudeapi-yolo -p "Please review latest changes and fix issues"

# manually
cd ~/my-project
docker run -it --rm \
  -v ${HOME}/.claude-claude1:/home/agent/.claude \
  -v ${PWD}:/workspace/$(basename ${PWD}):rslave \
  -w /workspace/$(basename ${PWD}) \
  ghcr.io/gw0/docker-claude-code:main claude
```

## Plugins

Many skills and plugins are re-packaged and pre-installed in the image and available via Claude Code's native plugin system. Use `/plugin` and `/reload-plugins` inside Claude Code to enable or disable them on-demand.

| Plugin | Source | Content |
|--------|--------|---------|
| `sc` | [SuperClaude Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework) | 39 commands, 25 agents, 1 skill |
| `cs` | [claude-skills](https://github.com/Jeffallan/claude-skills) | ~5 commands, 90 skills |
| `aas-essentials` | [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills) | 5 essential skills |
| `aas-security-engineer` | antigravity | 7 security skills |
| `aas-web-wizard` | antigravity | 7 web skills |
| `aas-python` | antigravity | 7 Python skills |
| `aas-devops` | antigravity | 7 DevOps skills |
| `aas-full` | antigravity | all 1,273+ skills |
| *(33 more aas-* bundles)* | antigravity | 5-8 skills each |

Set `ENABLE_PLUGINS` to a space-separated list of plugin names to select which plugins are enabled at startup (default: `sc`):

```bash
ENABLE_PLUGINS="aas-essentials aas-web-wizard" claude1
```

## Remote dev environment

Local Claude will edit files locally and execute docker exec commands in the remote dev environment.

1. Local: Claude container runs locally, edits files in workspace
2. Mutagen: Syncs workspace files bidirectionally (`local workspace <-> remote workspace`)
2. Mutagen: Forwards restricted remote Docker socket (`local port -> docker-proxy`)
3. Remote: Exposes restricted remote Docker socket (`docker-proxy -> remote Docker socket`)
3. Remote: Claude executes docker exec commands that run in dev-container (`docker exec -> -> dev-container`)

Install dependencies:

```bash
curl -Lo mutagen.tar.gz https://github.com/mutagen-io/mutagen/releases/download/v0.18.1/mutagen_linux_amd64_v0.18.1.tar.gz
tar -xzf mutagen.tar.gz -C ~/bin
```

In your project dir set up a containerized dev environment similar to `remote-example/`.

Start and manage a remote dev environment (via SSH):

```
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
DOCKER_HOST=tcp://127.0.0.1:2375 claude1

# manually
cd ~/my-project
docker run -it --rm \
  -v ${HOME}/.claude-claude1:/home/agent/.claude \
  -e DOCKER_HOST=tcp://127.0.0.1:2375 \
  --net host \
  --cap-drop ALL \
  -v ${PWD}:/workspace/$(basename ${PWD}):rslave \
  -w /workspace/$(basename ${PWD}) \
  ghcr.io/gw0/docker-claude-code:main claude
```

## License

Copyright &copy; 2025-2026 *gw0* [<http://gw.tnode.com/>] &lt;<gw.2026@ena.one>&gt;

All code is licensed under the GNU Affero General Public License 3.0+ (`AGPL-3.0-or-later`). Note that it is mandatory to make all modifications and complete source code publicly available to any user.
