#!/bin/bash
# Shim for /usr/bin/bwrap
#
# Rewrites problematic bwrap args when needed:
#   --unshare-pid   -> drop, due to [A]
#   --proc DEST     -> add --bind /proc DEST, due to [A]
#   --unshare-net   -> drop if gVisor, due to [B]
#   all             -> skip bwrap and apply-seccomp for excluded commands, due to [C]
#
# [A] Nested procfs mount failures (https://github.com/containers/bubblewrap/issues/284)
#     Fixes buggy enableWeakerNestedSandbox (https://github.com/anthropics/claude-code/issues/73786)
#     Error: "bwrap: Can't mount proc on /newroot/proc: Operation not permitted"
#     Activate: preserve_procns always.
#
# [B] bwrap's loopback setup fails under gVisor's netstack (https://github.com/containers/bubblewrap/issues/745)
#     Error: "loopback: Failed RTM_NEWADDR"
#     Activate: preserve_netns only if gVisor is detected.
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

preserve_procns=1
preserve_netns=0
[[ "$(</proc/sys/kernel/osrelease)" == *gvisor* ]] && preserve_netns=1

args=()
while (($#)); do
  case "$1" in
  --unshare-pid)
    [[ "${preserve_procns}" == 1 ]] || args+=("$1")
    shift
    ;;
  --proc)
    if [[ "${preserve_procns}" == 1 ]]; then
      args+=(--bind /proc "$2")
    else
      args+=("$1" "$2")
    fi
    shift 2
    ;;
  --unshare-net)
    [[ "${preserve_netns}" == 1 ]] || args+=("$1")
    shift
    ;;
  *)
    args+=("$1")
    shift
    ;;
  esac
done

exec "${real_bwrap}" "${args[@]}"
