#!/usr/bin/env bash
# Install or update the autonomous-mode skill for Claude Code.
#
#   curl -fsSL https://raw.githubusercontent.com/koffih/claude-skill-autonomous-mode/main/install.sh | bash
#
# Options (after `bash -s --` when piped):
#   --project     install into ./.claude/skills of the current directory
#   --uninstall   remove the installed skill
#   -h, --help    show this help
#
# The skill is a git clone, so running this again updates it (fast-forward only).
# Set SKILLS_DIR to install somewhere else than ~/.claude/skills.
set -euo pipefail

NAME="autonomous-mode"
REPO="koffih/claude-skill-autonomous-mode"
URL="https://github.com/$REPO.git"

BASE="${SKILLS_DIR:-$HOME/.claude/skills}"

usage() {
  cat <<USAGE
Install or update the $NAME skill for Claude Code.

  install.sh              install into ~/.claude/skills (or \$SKILLS_DIR), or update it
  install.sh --project    install into ./.claude/skills of the current directory
  install.sh --uninstall  remove it
USAGE
}
MODE="install"

for arg in "$@"; do
  case "$arg" in
    --project)   BASE="$PWD/.claude/skills" ;;
    --uninstall) MODE="uninstall" ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "unknown option: $arg (try --help)" >&2; exit 2 ;;
  esac
done

TARGET="$BASE/$NAME"

# True only for a real clone of this repository, so we never touch anything else.
is_our_clone() {
  [ -d "$TARGET/.git" ] && [ ! -L "$TARGET" ] &&
    git -C "$TARGET" remote get-url origin 2>/dev/null | grep -qi "github.com[:/]$REPO\(\.git\)\{0,1\}$"
}

if [ "$MODE" = uninstall ]; then
  if [ ! -e "$TARGET" ] && [ ! -L "$TARGET" ]; then
    echo "not installed: $TARGET"
    exit 0
  fi
  if ! is_our_clone; then
    echo "refusing to remove $TARGET: it is not a clone of $REPO. Remove it by hand if intended." >&2
    exit 1
  fi
  rm -rf -- "$TARGET"
  echo "removed: $TARGET"
  exit 0
fi

command -v git >/dev/null 2>&1 || { echo "git is required but not installed." >&2; exit 1; }

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  if ! is_our_clone; then
    echo "refusing to overwrite $TARGET: it exists and is not a clone of $REPO." >&2
    echo "Move or remove it, then run this again." >&2
    exit 1
  fi
  if ! git -C "$TARGET" diff --quiet || ! git -C "$TARGET" diff --cached --quiet; then
    echo "local changes in $TARGET: not updating, to avoid losing them." >&2
    exit 1
  fi
  git -C "$TARGET" pull --ff-only --quiet
  echo "updated:   $TARGET ($(git -C "$TARGET" rev-parse --short HEAD))"
else
  mkdir -p "$BASE"
  git clone --quiet --depth 1 "$URL" "$TARGET"
  echo "installed: $TARGET ($(git -C "$TARGET" rev-parse --short HEAD))"
fi

# Verify instead of promising.
if grep -q "^name: $NAME$" "$TARGET/SKILL.md" 2>/dev/null; then
  echo "verified:  SKILL.md is readable and named $NAME"
else
  echo "installation looks broken: $TARGET/SKILL.md missing or misnamed." >&2
  exit 1
fi

echo
echo "Start a new Claude Code session, then run:  /$NAME"
