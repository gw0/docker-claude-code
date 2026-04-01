#!/bin/bash
# Bash aliases for claude-cage
#
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc

CLAUDE_IMAGE=${CLAUDE_IMAGE:-ghcr.io/gw0/claude-cage:main}
CLAUDE_PROFILES=${CLAUDE_PROFILES:-cc1 cc2 ccapi}

_claude_run() {
  local profile="$1"; shift
  DOCKER_HOST=unix:///run/docker.sock docker run -it --rm \
    -u "$(id -u):$(id -g)" \
    -e HOME=/home/agent \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e CLAUDE_PROFILE="${profile}" \
    -e ENABLE_PLUGINS="${ENABLE_PLUGINS:-}" \
    -e FORCE_RESET_SESSIONS="${FORCE_RESET_SESSIONS:-}" \
    -e SKIP_SECURITY_SCAN="${SKIP_SECURITY_SCAN:-}" \
    -e DOCKER_HOST="${DOCKER_HOST:-}" \
    --net host \
    --cap-drop ALL \
    --security-opt=no-new-privileges:true \
    -v "${HOME}/.claude-${profile}:/home/agent/.claude" \
    -v "${PWD}:${PWD}:rslave" \
    -w "${PWD}" \
    ${CLAUDE_IMAGE} claude "$@"
}

for profile in ${CLAUDE_PROFILES}; do
  mkdir -vp ${HOME}/.claude-${profile}
  alias ${profile}="_claude_run ${profile}"
  alias ${profile}-yolo="SKIP_SECURITY_SCAN=1 _claude_run ${profile} --allow-dangerously-skip-permissions"
  alias ${profile}-advisor="SKIP_SECURITY_SCAN=1 _claude_run ${profile} --agent advisor"
done

