#!/bin/bash
# Shim for /usr/bin/bwrap
#
# Workaround for nested procfs mount failures (containers/bubblewrap#284):
#   bwrap: Can't mount proc on /newroot/proc: Operation not permitted
#   fixes buggy enableWeakerNestedSandbox (https://github.com/anthropics/claude-code/issues/73786)
#
# Rewrites problematic bwrap args:
#   --unshare-pid   -> dropped
#   --proc DEST     -> --bind /proc DEST
#
# Workaround to clean-up leftover sandbox placeholders https://github.com/anthropics/claude-code/issues/78072:
#   masked files/dirs for self-bind pre-created by Claude Code
#   bwrap pre-creates missing bind/dir targets, then unreliably fails to remove them
#
# Trade-off: Nested bwrap sandboxes lose PID-namespace isolation (full /proc
# visibility), but the container keeps --cap-drop ALL. Alternative is to grant
# required capabilities, or disable Claude Code's sandbox and env scrubbing.
set -euo pipefail

real_bwrap=/usr/bin/bwrap.real
args=()
watch_paths=()
#debug_log="${DEBUG_BWRAP_SHIM:-}"
debug_log="/tmp/bwrap-shim.log"
now=$(date +%s)

[[ -n "${debug_log}" ]] && echo "orig: $*" >>"${debug_log}"

while (($#)); do
  case "$1" in
  --unshare-pid)
    # Dropped due to nested procfs mount failures
    shift
    ;;
  --proc)
    # Rewrite due to nested procfs mount failures
    args+=(--bind /proc "$2")
    shift 2
    ;;
  --bind | --ro-bind | --dev-bind | --bind-try | --ro-bind-try | --dev-bind-try)
    # Watch for clean-up leftover sandbox placeholders
    args+=("$1" "$2" "$3")
    if [[ ! -e "$3" ]]; then
      watch_paths+=("$3")
    elif [[ "$2" == "$3" ]]; then
      # Self-bind pre-created by Claude Code (watch only if made moments ago)
      mtime=$(stat -c %Y "$3" 2>/dev/null || echo 0)
      ((now - mtime <= 5)) && watch_paths+=("$3")
    fi
    shift 3
    ;;
  --dir)
    # Watch for clean-up leftover sandbox placeholders
    args+=("$1" "$2")
    [[ -e "$2" ]] || watch_paths+=("$2")
    shift 2
    ;;
  *)
    args+=("$1")
    shift
    ;;
  esac
done

[[ -n "${debug_log}" ]] && echo "before:" >>"${debug_log}" && ls -al . >>"${debug_log}"

# Hook to clean-up leftover sandbox placeholders
if ((${#watch_paths[@]} > 0)); then
  fifo_dir=$(mktemp -d)
  fifo="${fifo_dir}/info.fifo"
  mkfifo "${fifo}"

  exec {info_fd}<>"${fifo}" # <> avoids blocking until a reader attaches
  args=(--info-fd "${info_fd}" "${args[@]}") # must precede the command

  (
    read -r _ <"${fifo}" || true
    rm -rf "${fifo_dir}"
    for p in "${watch_paths[@]}"; do
      [[ -f "${p}" && ! -s "${p}" ]] && rm -f "${p}"
      [[ -d "${p}" ]] && rmdir "${p}" 2>/dev/null || true
    done
    [[ -n "${debug_log}" ]] && echo "cleaned: ${watch_paths[*]}" >>"${debug_log}"
    [[ -n "${debug_log}" ]] && echo "after:" >>"${debug_log}" && ls -al . >>"${debug_log}"
  ) &
  disown
fi

# Run with modified args
[[ -n "${debug_log}" ]] && echo "final: ${args[*]}" >>"${debug_log}"
exec "${real_bwrap}" "${args[@]}"
