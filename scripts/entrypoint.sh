#!/bin/bash
# Docker entrypoint that sources bashrc

# Map current arbitrary UID/GID to "agent" so NSS resolution works
if ! getent passwd "$(id -u)" &>/dev/null; then
  export NSS_WRAPPER_PASSWD=/tmp/passwd
  export NSS_WRAPPER_GROUP=/tmp/group
  echo "agent:x:$(id -u):$(id -g):agent:/home/agent:/bin/bash" >"${NSS_WRAPPER_PASSWD}"
  echo "agent:x:$(id -g):" >"${NSS_WRAPPER_GROUP}"
  LD_PRELOAD=$(echo /usr/lib/*/libnss_wrapper.so)
  export LD_PRELOAD
fi

# Source .bashrc
# shellcheck disable=SC1090
[[ -f ~/.bashrc ]] && source ~/.bashrc

# Initialize dirs
export CLAUDE_CONFIG_DIR=~/.claude
mkdir -p ~/.claude/plugins/marketplaces/ ~/.claude/.gh-config/

# Initialize audit log (owner write-only to obscure access)
touch ~/.claude/audit-log.jsonl
chmod 200 ~/.claude/audit-log.jsonl

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
  claude plugins enable "${plugin}@local" >/dev/null 2>&1
done

# Skip security scans if non-interactive
for arg in "$@"; do
  case "${arg}" in
  -p | --print | -h | --help | -v | --version | agents | auth | doctor | install | mcp | plugin | plugins | setup-token | update | upgrade)
    DISABLE_SECURITY_SCAN=1
    break
    ;;
  *) ;;
  esac
done
unset arg

if [[ ! "${DISABLE_SECURITY_SCAN:-}" =~ ^[1YyTt]$ ]]; then
  # AgentShield security scan (non-blocking)
  agentshield scan --path ~/.claude/ --format terminal || true
  if [[ -d ".claude" ]]; then
    agentshield scan --path .claude/ --format terminal || true
  fi
  # Suspicious overrides in project .claude/
  if [[ -d ".claude" ]] && rg -qn 'enableAllProjectMcpServers|ANTHROPIC_BASE_URL|CLAUDE_BASE_URL' .claude/ 2>/dev/null; then
    echo "WARNING: Suspicious overrides detected in project .claude/!"
  fi
  # Hidden unicode scan (zero-width, bidi overrides/isolates, soft hyphen, interlinear annotation)
  if rg -qlP '[\x{00AD}\x{200B}\x{200C}\x{200D}\x{2060}\x{FEFF}\x{202A}-\x{202E}\x{2066}-\x{2069}\x{FFF9}-\x{FFFB}]' . 2>/dev/null; then
    echo "WARNING: Hidden Unicode characters detected in project files!"
  fi
  # Unicode tag block and variation selectors (invisible LLM prompt injection / stealth payload encoding)
  if rg -qlP '[\x{FE00}-\x{FE0F}\x{E0000}-\x{E007F}\x{E0100}-\x{E01EF}]' . 2>/dev/null; then
    echo "WARNING: Unicode tag or variation selector characters detected — possible invisible prompt injection!"
  fi
fi

# Startup notice
gh_user=$(gh config get -h github.com user 2>/dev/null)
git_author_name=$(git config --global author.name 2>/dev/null || git config --global user.name 2>/dev/null)
git_author_email=$(git config --global author.email 2>/dev/null || git config --global user.email 2>/dev/null)
git_committer_name=$(git config --global committer.name 2>/dev/null || git config --global user.name 2>/dev/null)
git_committer_email=$(git config --global committer.email 2>/dev/null || git config --global user.email 2>/dev/null)
[[ "${git_author_name}" == "${git_committer_name}" && "${git_author_email}" == "${git_committer_email}" ]] && unset git_committer_name git_committer_email
echo "# Profile: ${CLAUDE_PROFILE:-(unknown)} | GitHub: ${gh_user:-(none)} | Git: ${git_author_name:-(none)} <${git_author_email}>${git_committer_name:+, ${git_committer_name} <${git_committer_email}>}"
echo

exec "$@"
