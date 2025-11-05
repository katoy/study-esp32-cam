#!/usr/bin/env bash
# SDカードのファイルをツリー表示するスクリプト
# 使い方: ./tree_sd.sh <ESP32_IP> [--no-color]
# 例   : ./tree_sd.sh 192.168.0.49

set -euo pipefail

if [[ ${1:-} == "" ]]; then
  echo "Usage: $0 <ESP32_IP> [--no-color]" >&2
  exit 1
fi

HOST="$1"
NO_COLOR="false"
if [[ ${2:-} == "--no-color" ]]; then
  NO_COLOR="true"
fi

# 色設定（--no-color 指定で無効化）
if [[ "$NO_COLOR" == "false" ]]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  BLUE='\033[34m'
  GREEN='\033[32m'
  YELLOW='\033[33m'
  RESET='\033[0m'
else
  BOLD=''
  DIM=''
  BLUE=''
  GREEN=''
  YELLOW=''
  RESET=''
fi

# jq または python3 を使って JSON をパースする
have_jq() { command -v jq >/dev/null 2>&1; }
have_python() { command -v python3 >/dev/null 2>&1; }

fetch() {
  local path="$1"
  curl -fsSL "http://$HOST$path"
}

format_bytes() {
  # 引数: バイト数（整数） を人間向けに整形
  local bytes=$1
  local kb=$((1024))
  local mb=$((1024*1024))
  local gb=$((1024*1024*1024))
  if (( bytes >= gb )); then
    printf "%.1f GB" "$(awk -v b="$bytes" 'BEGIN{printf b/1073741824}')"
  elif (( bytes >= mb )); then
    printf "%.1f MB" "$(awk -v b="$bytes" 'BEGIN{printf b/1048576}')"
  elif (( bytes >= kb )); then
    printf "%.1f KB" "$(awk -v b="$bytes" 'BEGIN{printf b/1024}')"
  else
    printf "%d B" "$bytes"
  fi
}

# SD 情報を表示
print_sdinfo() {
  local json
  if ! json=$(fetch "/app/sdinfo"); then
    echo "${YELLOW}Warning:${RESET} /app/sdinfo の取得に失敗しました" >&2
    return 0
  fi

  if have_jq; then
    local total used files usage
    total=$(jq -r '.totalBytes' <<<"$json")
    used=$(jq -r '.usedBytes' <<<"$json")
    files=$(jq -r '.fileCount' <<<"$json")
    usage=$(jq -r '.usagePercent' <<<"$json")

    echo -e "${BOLD}SD Card Info${RESET}"
    echo "  Total: $(format_bytes "$total")"
    echo "  Used : $(format_bytes "$used")"
    echo "  Files: $files"
    echo "  Usage: ${usage}%"
    echo
  elif have_python; then
    python3 - <<'PY'
import json, sys
j=json.load(sys.stdin)
print('SD Card Info')
print('  Total:', j.get('totalBytes'))
print('  Used :', j.get('usedBytes'))
print('  Files:', j.get('fileCount'))
print('  Usage:', j.get('usagePercent'), '%')
PY
    echo
  else
    echo "$json" | sed 's/{/\n&/g; s/,/\n  &/g' | sed -n '1,10p'
    echo
  fi
}

# /photos 配下のファイル一覧（非再帰）をツリー風に表示
print_photos_tree() {
  local json
  if ! json=$(fetch "/app/files"); then
    echo "${YELLOW}Warning:${RESET} /app/files の取得に失敗しました" >&2
    return 1
  fi

  echo -e "${BOLD}SD Card (HTTP)${RESET}"
  echo "└── photos"

  if have_jq; then
    local count
    count=$(jq '.files | length' <<<"$json")
    if [[ "$count" == "0" ]]; then
      echo "    └── (empty)"
      return 0
    fi

    # 最終要素判定のために index を使う
    local i name size last
    last=$((count-1))
    for i in $(seq 0 "$last"); do
      name=$(jq -r ".files[$i].name" <<<"$json")
      size=$(jq -r ".files[$i].size" <<<"$json")
      local size_h
      size_h=$(format_bytes "$size")
      local branch="├"
      if [[ "$i" -eq "$last" ]]; then branch="└"; fi
      echo "    ${branch}── ${name} (${size_h})"
    done
  elif have_python; then
    python3 - <<'PY'
import json, sys, math
j=json.load(sys.stdin)
files=j.get('files', [])
if not files:
    print('    └── (empty)')
else:
    last=len(files)-1
    for i,f in enumerate(files):
        name=f.get('name','(unknown)')
        size=f.get('size',0)
        branch='└' if i==last else '├'
        print(f"    {branch}── {name} ({size} B)")
PY
  else
    # 簡易表示（jq/python 無し）
    # {"files":[{"name":"/photos/20250101-000000.jpg","size":12345}, ...]}
    echo "$json" \
      | sed 's/},/}\n/g' \
      | sed -n 's/.*"name":"\([^"]*\)","size":\([0-9]*\).*/    ├── \1 (\2 B)/p' \
      | sed '$ s/├──/└──/'
    # 空かもしれない場合の補助
    if ! grep -q '── ' <<<"$json"; then
      echo "    └── (empty)"
    fi
  fi
}

print_sdinfo
print_photos_tree
