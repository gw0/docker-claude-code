#!/bin/bash
# Shim for /usr/bin/bwrap
#
# Rewrites problematic bwrap args when needed:
#   --unshare-pid   -> drop, see [A]
#   --proc DEST     -> add --bind /proc DEST, see [A]
#   --unshare-net   -> drop if gVisor, see [B]
#   all             -> skip bwrap and apply-seccomp for excluded commands, see [C]
#
# [A] Nested procfs mount failures (https://github.com/containers/bubblewrap/issues/284)
#     Fixes buggy enableWeakerNestedSandbox (https://github.com/anthropics/claude-code/issues/73786)
#     Error: "bwrap: Can't mount proc on /newroot/proc: Operation not permitted"
#     Activate: DISABLE_BWRAP_PROCPS=1 always.
#
# [B] bwrap's loopback setup fails under gVisor's netstack (https://github.com/containers/bubblewrap/issues/745)
#     Error: "loopback: Failed RTM_NEWADDR"
#     Also needed to reach the docker.sock TCP relay (see entrypoint.sh), since
#     apply-seccomp blocks AF_UNIX outright.
#     Activate: DISABLE_BWRAP_NETNS=1 if gVisor is detected, or set to 1.
#
# [C] Fixes buggy sandbox.excludedCommands (https://github.com/anthropics/claude-code/issues/95813)
#     General escape hatch that skips both bwrap and apply-seccomp entirely.
#     Activate: fully unsandboxed commands if they start with excluded_cmds.
#
# Trade-off: Nested bwrap sandboxes lose the corresponding namespace isolation
# (full /proc visibility, shared network), but the container keeps --cap-drop
# ALL. Excluded commands get zero sandboxing. Alternative is to grant required
# capabilities, or disable Claude Code's sandboxed Bash tool and env scrubbing.
set -euo pipefail

real_bwrap=/usr/bin/bwrap.real

excluded_cmds=()
argv=("$@")
for ((i = 0; i < ${#argv[@]}; i++)); do
  if [[ "${argv[i]}" == "--" ]]; then
    rest="${argv[*]:i+1}"
    for cmd in "${excluded_cmds[@]}"; do
      cmd_regex="eval '(\"')*(rtk )?${cmd} "
      if [[ "${rest}" =~ ${cmd_regex} ]]; then
        target=("${argv[@]:i+1}")
        for ((j = 0; j < ${#target[@]}; j++)); do
          target[j]="$(sed -E 's|ARGV0=apply-seccomp[[:space:]]+/proc/self/fd/[0-9]+[[:space:]]+||' <<<"${target[j]}")"
        done
        exec "${target[@]}"
      fi
    done
    break
  fi
done

DISABLE_BWRAP_PROCPS=${DISABLE_BWRAP_PROCPS:-1}
DISABLE_BWRAP_NETNS=${DISABLE_BWRAP_NETNS:-0}
[[ "$(</proc/sys/kernel/osrelease)" == *gvisor* ]] && DISABLE_BWRAP_NETNS=1

args=()
while (($#)); do
  case "$1" in
  --unshare-pid)
    [[ "${DISABLE_BWRAP_PROCPS}" =~ ^[1YyTt]$ ]] || args+=("$1")
    shift
    ;;
  --proc)
    if [[ "${DISABLE_BWRAP_PROCPS}" =~ ^[1YyTt]$ ]]; then
      args+=(--bind /proc "$2")
    else
      args+=("$1" "$2")
    fi
    shift 2
    ;;
  --unshare-net)
    [[ "${DISABLE_BWRAP_NETNS}" =~ ^[1YyTt]$ ]] || args+=("$1")
    shift
    ;;
  *)
    args+=("$1")
    shift
    ;;
  esac
done

exec "${real_bwrap}" "${args[@]}"
