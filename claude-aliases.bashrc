#!/bin/bash
# Bash aliases for docker-claude-code
#
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc

CLAUDE_IMAGE=${CLAUDE_IMAGE:-ghcr.io/gw0/docker-claude-code:main}
CLAUDE_PROFILES=${CLAUDE_PROFILES:-cc1 cc2 ccapi}

_claude_run() {
  local profile="$1"; shift
  local script_dir="${BASH_SOURCE[0]:-$0}"; script_dir="${script_dir%/*}"
  docker run -it --rm \
    -u "$(id -u):$(id -g)" \
    -e HOME=/home/agent \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e CLAUDE_PROFILE="${profile}" \
    -e ENABLE_PLUGINS="${ENABLE_PLUGINS:-}" \
    -e FORCE_RESET_SESSIONS="${FORCE_RESET_SESSIONS:-}" \
    -e DISABLE_SECURITY_SCAN="${DISABLE_SECURITY_SCAN:-}" \
    -e DISABLE_RTK="${DISABLE_RTK:-}" \
    ${DOCKER_EXTRA_ARGS:-} \
    --cap-drop ALL \
    --security-opt=no-new-privileges:true \
    --security-opt seccomp=${script_dir}/claude-seccomp.json \
    -v "${HOME}/.claude-${profile}:/home/agent/.claude" \
    -v "${PWD}:${PWD}:rslave" \
    -w "${PWD}" \
    ${CLAUDE_IMAGE} claude "$@"
}

for profile in ${CLAUDE_PROFILES}; do
  mkdir -vp ${HOME}/.claude-${profile}
  alias ${profile}="_claude_run ${profile}"
  alias ${profile}-yolo="DISABLE_SECURITY_SCAN=1 _claude_run ${profile} --allow-dangerously-skip-permissions"
  alias ${profile}-advisor="DISABLE_SECURITY_SCAN=1 _claude_run ${profile} --permission-mode default --agent advisor"
done

