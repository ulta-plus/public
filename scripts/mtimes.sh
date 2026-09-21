#!/bin/bash
set -euo pipefail

git -c core.quotepath=off log --first-parent -m --no-renames --name-only --format=@%ct |
  awk '/^@[0-9]+$/ { time = substr($0, 2); next } NF && !seen[$0]++ { print time "\t" $0 }' |
  while IFS=$'\t' read -r time path; do
    if [ -f "$path" ]; then
      touch -d "@$time" "$path"
    fi
  done
