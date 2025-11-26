#!/bin/bash -i
# Docker entrypoint that sources bashrc

# Initialize claude env
export CLAUDE_CONFIG_DIR=~/.claude
ln -fsr .claude/.claude.json ~/.claude.json
ln -fsr .claude/.claude.json.backup ~/.claude.json.backup

# Force reset sessions
[[ "${FORCE_RESET_SESSIONS:-}" =~ ^[1YyTt]$ ]] && rm -vrf ~/.claude/{debug,file-history,plans,projects,session-env,shell-snapshots,todos}

# Remove dangling symlinks in claude dir
find ~/.claude -maxdepth 1 -type l ! -exec test -e {} \; -exec rm -vf {} \;

# Force recreate symlinks in claude dir
ln -fsr -t ~/.claude ~/.claude-shared/*

exec "$@"
