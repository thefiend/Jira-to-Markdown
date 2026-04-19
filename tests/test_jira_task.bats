#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/jira-task"

setup() {
  TEST_DIR="$BATS_TEST_TMPDIR"
  mkdir -p "$TEST_DIR/bin"
  export JIRA_TASK_ZSHRC="$TEST_DIR/.zshrc"
}

@test "exits with error if jq is not installed" {
  run env PATH="$TEST_DIR/bin" /bin/bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required. Install with: brew install jq"* ]]
}
