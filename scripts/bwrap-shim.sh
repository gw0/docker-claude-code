#!/bin/bash
# Shim for /usr/bin/bwrap
#
# Rewrites problematic bwrap args:
#   --unshare-pid   -> dropped due to [A]
#   --proc DEST     -> --bind /proc DEST, due to [A]
#   --unshare-net   -> dropped due to [B]
#
# [A] Nested procfs mount failures (https://github.com/containers/bubblewrap/issues/284):
#       bwrap: Can't mount proc on /newroot/proc: Operation not permitted
#     Fixes buggy enableWeakerNestedSandbox (https://github.com/anthropics/claude-code/issues/73786)
#
# [B] bwrap's loopback setup fails under gVisor's netstack
#     (https://github.com/containers/bubblewrap/issues/745)
#
# Trade-off: Nested bwrap sandboxes lose PID- and network-namespace
# isolation (full /proc visibility, shared network with the container),
# but the container keeps --cap-drop ALL. Alternative is to grant
# required capabilities, or disable Claude Code's sandbox and env scrubbing.
set -euo pipefail

real_bwrap=/usr/bin/bwrap.real
args=()

while (($#)); do
  case "$1" in
  --unshare-pid)
    shift
    ;;
  --unshare-net)
    shift
    ;;
  --proc)
    shift
    args+=(--bind /proc "$1")
    shift
    ;;
  *)
    args+=("$1")
    shift
    ;;
  esac
done

exec "${real_bwrap}" "${args[@]}"
