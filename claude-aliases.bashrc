#!/bin/bash
# Bash aliases for containerized Claude Code
#
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc

alias claude="docker run -it --rm \
  -v \${HOME}/.claude:/home/agent/.claude \
  -v \${PWD}:/workspace:rslave \
  -w /workspace \
  -e ANTHROPIC_API_KEY=\${ANTHROPIC_API_KEY} \
  -e DISPLAY=\${DISPLAY} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DOCKER_HOST=\${DEV_DOCKER_HOST} \
  --net host \
  \${CLAUDE_IMAGE} claude
"
