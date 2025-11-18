#!/bin/bash
# Bash aliases for containerized Claude Code
#
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc

# Create claude-{agent} aliases
CLAUDE_IMAGE=${CLAUDE_IMAGE:-ghcr.io/gw0/docker-claude-code:main}
for agent in ~/.claude/agents/*.md; do
  [[ -f "$agent" ]] || continue
  agent=$(basename "$agent" .md)
  alias claude-${agent}="docker run -it --rm \
    -v \${HOME}/.claude:/home/agent/.claude \
    -v \${PWD}:/workspace:rslave \
    -w /workspace \
    -e ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY} \
    -e DISPLAY=\${DISPLAY} \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DOCKER_HOST=\${DEV_DOCKER_HOST} \
    --net host \
    \${CLAUDE_IMAGE} claude --append-system-prompt \"\$(cat \${HOME}/.claude/agents/${agent}.md)\"
  "
done
