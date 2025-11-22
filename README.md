# Containerized Claude Code and AI agents

Docker environment for running Claude Code with isolated AI agents and SuperClaude integration.

## Build

```bash
docker build -t claude .
# or pull latest:
docker pull ghcr.io/gw0/docker-claude-code:main
```

## Install

For shell integration update `~/.bashrc` (replace `/path/to`):

```bash
echo "source /path/to/claude-aliases.bashrc" >> ~/.bashrc
source /path/to/claude-aliases.bashrc
```

For additional sandbox allow usage of unprivileged user namespaces from bubblewrap:

```bash
echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/50-bubblewrap.conf
sudo sysctl -w kernel.unprivileged_userns_clone=1
```

## Usage

```bash
# with shell integration
cd ~/my-project
claude
# or:
claude "Please review latest changes"

# switch from subscription to API usage
(ANTHROPIC_API_KEY=$(cat ~/.claude/anthropic_api_key.key); claude)

# manually
cd ~/my-project
docker run -it --rm \
  -v ${HOME}/.claude:/home/agent/.claude \
  -v ${PWD}:/workspace:rslave \
  -w /workspace \
  -e DISPLAY=${DISPLAY} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  ghcr.io/gw0/docker-claude-code:main claude
```

Check SuperClaude commands to follow a structured workflow:

- https://github.com/SuperClaude-Org/SuperClaude_Framework

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
export DEV_DOCKER_HOST=tcp://127.0.0.1:2375
claude-code

# manually
cd ~/my-project
docker run -it --rm \
  -v ${HOME}/.claude:/home/agent/.claude \
  -v ${PWD}:/workspace:rslave \
  -w /workspace \
  -e DISPLAY=${DISPLAY} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DOCKER_HOST=tcp://127.0.0.1:2375 \
  --net host \
  ghcr.io/gw0/docker-claude-code:main claude
```

## License

Copyright &copy; 2025 *gw0* [<http://gw.tnode.com/>] &lt;<gw.2025@ena.one>&gt;

All code is licensed under the GNU Affero General Public License 3.0+ (`AGPL-3.0-or-later`). Note that it is mandatory to make all modifications and complete source code publicly available to any user.
