#!/usr/bin/env bash
# Kör NVIDIA SkillSpector över alla skills i plugins/ och rapporterar bara NYA fynd,
# dvs sådant som inte redan är granskat och accepterat i baselines/<skill>.yaml.
#
#   scripts/scan.sh              # alla skills, statisk analys
#   scripts/scan.sh impeccable   # en skill
#
# Kräver: uv tool install git+https://github.com/NVIDIA/skillspector.git
# Uppdatera en baseline efter granskning av nya fynd:
#   skillspector baseline plugins/<skill>/skills/<skill> --no-llm -o baselines/<skill>.yaml
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
command -v skillspector >/dev/null || { echo "skillspector saknas: uv tool install git+https://github.com/NVIDIA/skillspector.git" >&2; exit 2; }

skills=("$@")
[ ${#skills[@]} -eq 0 ] && skills=($(ls "$ROOT/plugins"))

status=0
for s in "${skills[@]}"; do
  dir="$ROOT/plugins/$s/skills/$s"
  base="$ROOT/baselines/$s.yaml"
  [ -f "$dir/SKILL.md" ] || { echo "== $s: ingen SKILL.md, hoppar över"; continue; }
  echo "== $s"
  if [ -f "$base" ]; then
    skillspector scan "$dir" --no-llm --baseline "$base" || status=1
  else
    echo "   (ingen baseline i baselines/$s.yaml – visar alla fynd)"
    skillspector scan "$dir" --no-llm || status=1
  fi
done
exit $status
