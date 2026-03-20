#!/bin/bash -i
# Docker entrypoint that sources bashrc

# Initialize claude env
export CLAUDE_CONFIG_DIR=~/.claude
ln -fsr .claude/.claude.json ~/.claude.json
ln -fsr .claude/.claude.json.backup ~/.claude.json.backup

# Force reset sessions
[[ "${FORCE_RESET_SESSIONS:-}" =~ ^[1YyTt]$ ]] && rm -vrf ~/.claude/{debug,file-history,memory,plans,projects,session-env,shell-snapshots,todos}

# Remove dangling symlinks in claude dir
find ~/.claude -maxdepth 1 -type l ! -exec test -e {} \; -exec rm -vf {} \;

# Force recreate symlinks in claude dir
ln -fsr -t ~/.claude ~/.claude-shared/*

# AgentShield security scan (non-blocking)
agentshield scan --path ~/.claude --format terminal || true
if [ -d ".claude" ]; then
  agentshield scan --path .claude --format terminal || true
fi

# Hidden unicode scan (zero-width, bidi overrides)
if rg -qlP '[\x{200B}\x{200C}\x{200D}\x{2060}\x{FEFF}\x{202A}-\x{202E}]' . 2>/dev/null; then
  echo "WARNING: Hidden Unicode characters detected in project files!"
fi
# Suspicious overrides in project .claude/
if [ -d ".claude" ] && rg -qn 'enableAllProjectMcpServers|ANTHROPIC_BASE_URL' .claude/ 2>/dev/null; then
  echo "WARNING: Suspicious overrides detected in project .claude/!"
fi

exec "$@"
