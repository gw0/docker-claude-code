#!/bin/bash
# Bash aliases for containerized Claude Code
#
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc

CLAUDE_IMAGE=${CLAUDE_IMAGE:-ghcr.io/gw0/docker-claude-code:main}

alias claude="docker run -it --rm \
  -v \${HOME}/.claude:/home/agent/.claude \
  -v \${PWD}:/workspace/\$(basename \${PWD}):rslave \
  -w /workspace/\$(basename \${PWD}) \
  -e FORCE_DEFAULTS=\${FORCE_DEFAULTS} \
  -e FORCE_RESET_SESSIONS=\${FORCE_RESET_SESSIONS} \
  -e ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY} \
  -e DISPLAY=\${DISPLAY} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DOCKER_HOST=\${DEV_DOCKER_HOST} \
  --net host \
  --cap-drop ALL \
  \${CLAUDE_IMAGE} claude
"
