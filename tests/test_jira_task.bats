#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/jira-task"

setup() {
  TEST_DIR="$BATS_TEST_TMPDIR"
  mkdir -p "$TEST_DIR/bin"
  export JIRA_TASK_ZSHRC="$TEST_DIR/.zshrc"
}
