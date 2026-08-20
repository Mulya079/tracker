#!/bin/bash
# SessionStart hook — makes the Mulya079/agent_skills library available as
# personal skills in this Claude Code on the web session.
set -euo pipefail

# Local sessions manage their own environment.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Sync personal skills library (Mulya079/agent_skills) into ~/.claude/skills
# so every vendored skill is available as a personal skill in this session.
# Tolerant of failure: a broken skills sync should never block the session.
SKILLS_SRC="$HOME/.claude/skills-src/agent-skills"
if [ -d "$SKILLS_SRC/.git" ]; then
  git -C "$SKILLS_SRC" pull --ff-only || echo "skills sync: pull failed, using cached copy"
else
  rm -rf "$SKILLS_SRC"
  git clone --depth 1 https://github.com/Mulya079/agent_skills "$SKILLS_SRC" || echo "skills sync: clone failed, skipping"
fi
[ -x "$SKILLS_SRC/scripts/link-skills.sh" ] && "$SKILLS_SRC/scripts/link-skills.sh"
