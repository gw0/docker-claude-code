#!/bin/bash
# Bash aliases for containerized Claude Code
#
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc

CLAUDE_IMAGE=${CLAUDE_IMAGE:-ghcr.io/gw0/docker-claude-code:main}

CLAUDE_PROFILES=${CLAUDE_PROFILES:-claude1 claude2 claudeapi}
for profile in ${CLAUDE_PROFILES}; do
  mkdir -p ${HOME}/.claude-${profile}
  alias ${profile}="docker run -it --rm \
    -v \${HOME}/.claude-${profile}:/home/agent/.claude \
    -e FORCE_RESET_SESSIONS=\${FORCE_RESET_SESSIONS:-} \
    -e DISPLAY=\${DISPLAY:-} \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DOCKER_HOST=\${DOCKER_HOST:-} \
    --net host \
    --cap-drop ALL \
    -v \${PWD}:/workspace/\$(basename \${PWD}):rslave \
    -w /workspace/\$(basename \${PWD}) \
    \${CLAUDE_IMAGE} claude
  "
done

CLAUDE_ADVISOR_PROFILE="claude2"
alias claude-advisor=="docker run -it --rm \
  -v \${HOME}/.claude-${CLAUDE_ADVISOR_PROFILE}:/home/agent/.claude \
  -e FORCE_RESET_SESSIONS=\${FORCE_RESET_SESSIONS:-} \
  -e DISPLAY=\${DISPLAY:-} \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DOCKER_HOST=\${DOCKER_HOST:-} \
  --net host \
  --cap-drop ALL \
  -v \${PWD}:/workspace/\$(basename \${PWD}):rslave \
  -w /workspace/\$(basename \${PWD}) \
  \${CLAUDE_IMAGE} claude
"
