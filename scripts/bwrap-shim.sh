#!/bin/bash
# Shim for /usr/bin/bwrap
#
# Workaround for nested procfs mount failures (containers/bubblewrap#284):
#   bwrap: Can't mount proc on /newroot/proc: Operation not permitted
#   fixes buggy enableWeakerNestedSandbox https://github.com/anthropics/claude-code/issues/73786
#
# Rewrites problematic bwrap args:
#   --unshare-pid   -> dropped
#   --proc DEST     -> --bind /proc DEST
#
# Trade-off: Nested bwrap sandboxes lose PID-namespace isolation (full /proc
# visibility), but the container keeps --cap-drop ALL. Alternative is to grant
# required capabilities, or disable Claude Code's sandbox and env scrubbing.
set -euo pipefail

real_bwrap=/usr/bin/bwrap.real
args=()

while (($#)); do
  case "$1" in
  --unshare-pid)
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
