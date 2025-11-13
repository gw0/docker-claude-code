#!/bin/bash
# Bash aliases for containerized Claude Code
#
#   echo 'source /path/to/claude-aliases.bashrc' >> ~/.bashrc

# Create claude-{agent} aliases
AGENTS=(code debug docs plan2 refactor research review test security)
for agent in "${AGENTS[@]}"; do
  alias claude-${agent}="docker run -it --rm -v \${HOME}/.claude:/home/agent/.claude -v \${PWD}:/workspace:rslave -w /workspace -e DISPLAY=\${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix claude claude --append-system-prompt \"\$(cat \${HOME}/.claude/agents/${agent}.md)\""
done
