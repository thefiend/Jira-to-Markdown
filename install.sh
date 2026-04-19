#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/bin"

mkdir -p "$INSTALL_DIR"
cp "$SCRIPT_DIR/jira-task" "$INSTALL_DIR/jira-task"
chmod +x "$INSTALL_DIR/jira-task"

echo "Installed to $INSTALL_DIR/jira-task"
echo ""
echo "Make sure $INSTALL_DIR is in your PATH by adding to ~/.zshrc:"
echo "  export PATH=\"\$HOME/bin:\$PATH\""
echo ""
echo "Then run: jira-task --config"
