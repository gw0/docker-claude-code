#!/bin/bash
# Docker entrypoint that sources bashrc

[[ -f ~/.bashrc ]] && source ~/.bashrc

# Initialize claude env
export CLAUDE_CONFIG_DIR=~/.claude
mkdir -p ~/.claude/plugins/marketplaces

# Force reset sessions
if [[ "${FORCE_RESET_SESSIONS:-}" =~ ^[1YyTt]$ ]]; then
  rm -vrf ~/.claude/{cache,debug,file-history,memory,paste-cache,plans,projects,session-env,sessions,shell-snapshots,tasks,todos}
fi

# Remove dangling symlinks in claude dir
find ~/.claude -maxdepth 1 -type l ! -exec test -e {} \; -exec rm -vf {} \;
find ~/.claude/plugins/marketplaces -maxdepth 1 -type l ! -exec test -e {} \; -exec rm -vf {} \;

# Force recreate symlinks in claude dir
ln -fsr -t ~/.claude ~/.claude-shared/*
ln -fsr -t ~/.claude/plugins/marketplaces ~/.claude-shared/plugins-marketplaces/*

# Setup local plugins
claude plugins marketplace add ~/.claude/plugins/marketplaces/local >/dev/null
for plugin in ${ENABLE_PLUGINS:-sc codemap}; do
  claude plugins enable "${plugin}@local" >/dev/null
done

# Skip security scans if non-interactive
for arg in "$@"; do
  case "$arg" in
    -p|--print|-h|--help|-v|--version|agents|auth|doctor|install|mcp|plugin|plugins|setup-token|update|upgrade) SKIP_SECURITY_SCAN=1; break ;;
  esac
done
unset arg

if [[ ! "${SKIP_SECURITY_SCAN:-}" =~ ^[1YyTt]$ ]]; then
  # AgentShield security scan (non-blocking)
  agentshield scan --path ~/.claude/ --format terminal || true
  if [[ -d ".claude" ]]; then
    agentshield scan --path .claude/ --format terminal || true
  fi
  # Suspicious overrides in project .claude/
  if [[ -d ".claude" ]] && rg -qn 'enableAllProjectMcpServers|ANTHROPIC_BASE_URL' .claude/ 2>/dev/null; then
    echo "WARNING: Suspicious overrides detected in project .claude/!"
  fi
  # Hidden unicode scan (zero-width, bidi overrides)
  if rg -qlP '[\x{200B}\x{200C}\x{200D}\x{2060}\x{FEFF}\x{202A}-\x{202E}]' . 2>/dev/null; then
    echo "WARNING: Hidden Unicode characters detected in project files!"
  fi
fi

exec "$@"
