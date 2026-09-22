#!/bin/bash
# Bash aliases for docker-claude-code
#
# Configure profiles and pin to a version tag:
#   echo 'export CLAUDE_IMAGE=ghcr.io/gw0/docker-claude-code:v0.9.0' >> ~/.bashrc
#   echo 'export CLAUDE_PROFILES="cc1 ccpersonal ccapi"' >> ~/.bashrc
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc
#
# Usage: <profile>-<mode> [<dir>...] [<docker-args>] -- [<claude-args>]

CLAUDE_IMAGE=${CLAUDE_IMAGE:-ghcr.io/gw0/docker-claude-code:main}
CLAUDE_PROFILES=${CLAUDE_PROFILES:-cc1 cc2 ccpersonal ccapi}

_claude_run() {
  local profile="$1"; shift
  local script_dir="${BASH_SOURCE[0]:-$0}"; script_dir="${script_dir%/*}"
  local vol_opts=":rslave"
  [[ "$(uname)" == "Darwin" ]] && vol_opts=""
  local runtime_name=""
  if [[ ! "${DISABLE_GVISOR:-}" =~ ^[1YyTt]$ ]] && docker info --format '{{range $k, $v := .Runtimes}}{{println $k}}{{end}}' 2>/dev/null | grep -qx 'runsc'; then
    runtime_name="runsc"
  fi

  # Split args into dirs, docker-args, and claude-args
  local dirs=() docker_args=() claude_args=() phase=dirs tok
  for tok in "$@"; do
    if [[ "${phase}" == "claude" ]]; then
      claude_args+=("${tok}")
    elif [[ "${tok}" == "--" ]]; then
      phase="claude"
    elif [[ "${phase}" == "dirs" && "${tok}" != -* ]]; then
      dirs+=("${tok}")
    else
      phase="docker"
      docker_args+=("${tok}")
    fi
  done
  [[ ${#dirs[@]} -eq 0 ]] && dirs=("${PWD}")

  # Resolve dirs to absolute host paths (mount each at the same path, first dir is the workdir)
  local dir abs_dir primary_dir="" mount_args=()
  for dir in "${dirs[@]}"; do
    abs_dir="$(cd -- "${dir}" 2>/dev/null && pwd -P)" || {
      echo "error: directory not found: ${dir}" >&2
      return 1
    }
    [[ -z "${primary_dir}" ]] && primary_dir="${abs_dir}"
    mount_args+=(-v "${abs_dir}:${abs_dir}${vol_opts}")
  done

  # Run rootless container
  #
  # Trade-off: Rootless with capabilities dropped. Seccomp removes unused
  # syscalls and only adds syscalls nested bwrap needs (no CAP_SYS_ADMIN).
  # AppArmor stays unconfined for root-free setup. gVisor (runsc) adds an
  # extra syscall-isolation layer if available.

  docker run -it --rm \
    -u "$(id -u):$(id -g)" \
    -e HOME=/home/agent \
    -e ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}" \
    -e CLAUDE_CODE_OAUTH_TOKEN="${CLAUDE_CODE_OAUTH_TOKEN:-}" \
    -e CLAUDE_PROFILE="${profile}" \
    -e ENABLE_PLUGINS="${ENABLE_PLUGINS:-}" \
    -e FORCE_RESET_SESSIONS="${FORCE_RESET_SESSIONS:-}" \
    -e DISABLE_SCAN="${DISABLE_SCAN:-${DISABLE_SECURITY_SCAN:-}}" \
    -e DISABLE_NOTICE="${DISABLE_NOTICE:-}" \
    -e DISABLE_RTK="${DISABLE_RTK:-}" \
    --cap-drop ALL \
    --security-opt no-new-privileges=true \
    --security-opt apparmor=unconfined \
    --security-opt seccomp=${script_dir}/claude-seccomp.json \
    --runtime "${runtime_name}" \
    -v "${HOME}/.claude-${profile}:/home/agent/.claude" \
    "${mount_args[@]}" \
    -w "${primary_dir}" \
    ${DOCKER_EXTRA_ARGS:-} \
    "${docker_args[@]}" \
    ${CLAUDE_IMAGE} claude ${CLAUDE_EXTRA_ARGS:-} "${claude_args[@]}"
}

# Set up aliases: one per profile/account for each mode
for profile in ${CLAUDE_PROFILES}; do
  mkdir -vp "${HOME}/.claude-${profile}"
  alias ${profile}="_claude_run ${profile}"
  alias ${profile}-yolo="DISABLE_SCAN=1 CLAUDE_EXTRA_ARGS='--allow-dangerously-skip-permissions' _claude_run ${profile}"
  alias ${profile}-advisor="DISABLE_SCAN=1 CLAUDE_EXTRA_ARGS='--permission-mode default --agent advisor' _claude_run ${profile}"
done

