# Containerized Claude Code and AI agents

Docker environment for running Claude Code with isolated AI agents.

## Build

```bash
docker build --build-arg CLAUDE_VERSION=2.0.37 -t claude .
```

## Usage

### Claude Code with agent

```bash
docker run -it --rm \
  -v ${HOME}/.claude:/home/agent/.claude \
  -v ${PWD}:/workspace:rslave \
  -w /workspace \
  -e DISPLAY=${DISPLAY} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  ghcr.io/gw0/docker-claude-code:main claude --append-system-prompt "$(cat ${HOME}/.claude/agents/research.md)"
```

## Shell integration

Add to `~/.bashrc` and restart shell:

```bash
source /path/to/claude-aliases.bashrc
```

Usage:

```bash
cd ~/my-project
claude-code
# or
claude-review "Review recent changes"
```

## Available specialized agents

| Agent | Description |
|-------|-------------|
| `code` | Code writer/developer |
| `debug` | Code debugger |
| `docs` | Documentation writer/maintainer |
| `plan2` | Solution planner/architect |
| `refactor` | Code refactorer |
| `research` | Researcher/advisor |
| `review` | Code reviewer |
| `test` | Test runner and validator |
| `security` | Security auditor |

## License

Copyright &copy; 2025 *gw0* [<http://gw.tnode.com/>] &lt;<gw.2025@ena.one>&gt;

All code is licensed under the GNU Affero General Public License 3.0+ (`AGPL-3.0-or-later`). Note that it is mandatory to make all modifications and complete source code publicly available to any user.
