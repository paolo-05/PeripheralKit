#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
cd "$project_dir"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift build -c release --disable-sandbox
