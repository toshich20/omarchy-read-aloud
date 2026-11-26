#!/usr/bin/env bash
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINK="$HOME/.local/bin/read-selection"

mkdir -p "$(dirname "$LINK")"
if [[ -e "$LINK" && ! -L "$LINK" ]]; then
  rm -f "$LINK"
fi
ln -sfn "$SRC/bin/read-aloud" "$LINK"
chmod +x "$SRC/bin/read-aloud" "$SRC/bin/read-aloud-ctl" "$SRC/bin/read-aloud-prepare" "$SRC/bin/read-aloud-save" "$SRC/bin/read-aloud-tts" "$SRC/bin/split-text.py"
