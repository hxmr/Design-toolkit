#!/usr/bin/env bash
# Hämtar senaste versionen av varje upstream-repo och bygger om plugins/.
# Körs dagligen av .github/workflows/sync.yml, men kan också köras lokalt.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

clone() { # clone <owner/repo> <dir>
  git clone -q --depth 1 "https://github.com/$1.git" "$WORK/$2"
  echo "$1 $(git -C "$WORK/$2" rev-parse HEAD)" >> "$WORK/UPSTREAM.lock"
}

clone Leonxlnx/taste-skill         taste
clone pbakaus/impeccable           impeccable
clone microsoft/playwright-cli      playwright
clone img2threejs/img2threejs       img2three
clone VoltAgent/awesome-design-md   designmd

P="$ROOT/plugins"
rm -rf "$P"
mkdir -p "$P"

manifest() { # manifest <dir> <name> <description> <repo>
  mkdir -p "$1/.claude-plugin"
  cat > "$1/.claude-plugin/plugin.json" <<EOF
{
  "name": "$2",
  "description": "$3",
  "repository": "https://github.com/$4",
  "skills": "./skills/"
}
EOF
}

# 1. taste-skill
mkdir -p "$P/taste-skill/skills"
cp -R "$WORK/taste/skills/taste-skill" "$P/taste-skill/skills/taste-skill"
cp "$WORK/taste/LICENSE" "$P/taste-skill/"
manifest "$P/taste-skill" taste-skill \
  "Art direction for websites, product pages, dashboards and app screens, checked in a real browser." \
  Leonxlnx/taste-skill

# 2. impeccable (upstream already ships a Claude plugin folder)
cp -R "$WORK/impeccable/plugin" "$P/impeccable"
rm -rf "$P/impeccable/.grok-plugin"
cp "$WORK/impeccable/LICENSE" "$P/impeccable/"
[ -f "$WORK/impeccable/NOTICE.md" ] && cp "$WORK/impeccable/NOTICE.md" "$P/impeccable/"
# Låt versionen följa commit-SHA så att varje upstream-ändring syns som en ny version.
python3 - "$P/impeccable/.claude-plugin/plugin.json" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.pop("version", None)
json.dump(d, open(p, "w"), indent=2)
PY

# 3. playwright-cli (skill only; the CLI itself is installed with npm)
mkdir -p "$P/playwright-cli/skills"
cp -R "$WORK/playwright/skills/playwright-cli" "$P/playwright-cli/skills/playwright-cli"
cp "$WORK/playwright/LICENSE" "$P/playwright-cli/"
manifest "$P/playwright-cli" playwright-cli \
  "Browser automation and Playwright testing through the playwright-cli command (requires: npm install -g @playwright/cli@latest)." \
  microsoft/playwright-cli

# 4. img2threejs (the skill runs from its repo root: SKILL.md + forge/ + grimoire/ ...)
S="$P/img2threejs/skills/img2threejs"
mkdir -p "$S"
( cd "$WORK/img2three" && tar --exclude=.git --exclude=.github --exclude=assets \
    --exclude=bin --exclude=package.json -cf - . ) | ( cd "$S" && tar -xf - )
cp "$WORK/img2three/LICENSE" "$P/img2threejs/"
manifest "$P/img2threejs" img2threejs \
  "Rebuild the object in a reference image as a procedural, animation-ready Three.js model (requires Python 3.10+ locally)." \
  img2threejs/img2threejs

# 5. awesome-design-md, packaged as a skill with the DESIGN.md files as references
D="$P/design-md-library/skills/design-md-library"
mkdir -p "$D/designs"
for dir in "$WORK/designmd/design-md"/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/DESIGN.md" ] && { mkdir -p "$D/designs/$name"; cp "$dir/DESIGN.md" "$D/designs/$name/"; }
done
cp "$WORK/designmd/LICENSE" "$P/design-md-library/"
list="$(ls "$D/designs" | paste -sd ' ' -)"
cat > "$D/SKILL.md" <<EOF
---
name: design-md-library
description: Library of DESIGN.md design-system files extracted from well-known brand sites (Stripe, Linear, Vercel, Apple, Notion and more). Use when the user wants a UI that looks like a named brand or site, asks for a DESIGN.md, or wants a ready-made visual language to build from.
---

# DESIGN.md library

Each folder under \`designs/\` holds one \`DESIGN.md\`: colours with roles, typography, components,
layout, elevation, do's and don'ts, responsive rules and prompt notes for one site.

## How to use

1. Match the user's request to a folder name in \`designs/\`. If they name a brand that is not
   listed, say so and offer the closest match.
2. Read that \`designs/<name>/DESIGN.md\` in full before writing any UI.
3. Build the UI to its tokens and rules. If the user is working in a project, offer to copy the
   file into the project root as \`DESIGN.md\` so later work follows it too.
4. These files describe public visual styles. Do not copy logos, wordmarks or trademarked names
   into the output; use the style, not the brand.

## Available designs

$list

Source: https://github.com/VoltAgent/awesome-design-md (MIT).
EOF
manifest "$P/design-md-library" design-md-library \
  "DESIGN.md design-system files from well-known brand sites, for building UI in a given visual language." \
  VoltAgent/awesome-design-md

cp "$WORK/UPSTREAM.lock" "$ROOT/UPSTREAM.lock"
echo "Synced:"; cat "$ROOT/UPSTREAM.lock"
