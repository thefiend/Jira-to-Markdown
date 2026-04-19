#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/jira-task"

setup() {
  TEST_DIR="$BATS_TEST_TMPDIR"
  mkdir -p "$TEST_DIR/bin"
  export JIRA_TASK_ZSHRC="$TEST_DIR/.zshrc"
}

setup_mock_curl() {
  local status_code="$1"
  local body="${2:-{}}"
  printf '%s' "$body" > "$TEST_DIR/mock_body.json"
  printf '%s' "$status_code" > "$TEST_DIR/mock_status.txt"

  cat > "$TEST_DIR/bin/curl" << 'CURL_EOF'
#!/usr/bin/env bash
TEST_BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$(dirname "$TEST_BIN_DIR")"
i=1
while [ $i -le $# ]; do
  if [ "${!i}" = "-o" ]; then
    j=$((i+1))
    cp "$TEST_DIR/mock_body.json" "${!j}"
  fi
  i=$((i+1))
done
cat "$TEST_DIR/mock_status.txt"
CURL_EOF
  chmod +x "$TEST_DIR/bin/curl"
}

@test "exits with error if jq is not installed" {
  run env PATH="$TEST_DIR/bin" /bin/bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required. Install with: brew install jq"* ]]
}

@test "--config writes JIRA_URL to .zshrc" {
  run bash -c "printf 'https://test.atlassian.net\ntest@example.com\nmy-token\n' | JIRA_TASK_ZSHRC='$JIRA_TASK_ZSHRC' bash '$SCRIPT' --config"
  [ "$status" -eq 0 ]
  grep -q 'export JIRA_URL="https://test.atlassian.net"' "$JIRA_TASK_ZSHRC"
}

@test "--config writes JIRA_EMAIL to .zshrc" {
  run bash -c "printf 'https://test.atlassian.net\ntest@example.com\nmy-token\n' | JIRA_TASK_ZSHRC='$JIRA_TASK_ZSHRC' bash '$SCRIPT' --config"
  grep -q 'export JIRA_EMAIL="test@example.com"' "$JIRA_TASK_ZSHRC"
}

@test "--config writes JIRA_API_TOKEN to .zshrc" {
  run bash -c "printf 'https://test.atlassian.net\ntest@example.com\nmy-token\n' | JIRA_TASK_ZSHRC='$JIRA_TASK_ZSHRC' bash '$SCRIPT' --config"
  grep -q 'export JIRA_API_TOKEN="my-token"' "$JIRA_TASK_ZSHRC"
}

@test "--config updates existing var without duplicating" {
  echo 'export JIRA_URL="https://old.atlassian.net"' > "$JIRA_TASK_ZSHRC"
  run bash -c "printf 'https://new.atlassian.net\nnew@example.com\nnew-token\n' | JIRA_TASK_ZSHRC='$JIRA_TASK_ZSHRC' bash '$SCRIPT' --config"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'JIRA_URL' "$JIRA_TASK_ZSHRC")" -eq 1 ]
  grep -q 'export JIRA_URL="https://new.atlassian.net"' "$JIRA_TASK_ZSHRC"
}

@test "exits with message if JIRA_URL is missing" {
  run env JIRA_URL="" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing config. Run: jira-task --config"* ]]
}

@test "exits with message if JIRA_EMAIL is missing" {
  run env JIRA_URL="https://x.atlassian.net" JIRA_EMAIL="" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing config. Run: jira-task --config"* ]]
}

@test "exits with message if JIRA_API_TOKEN is missing" {
  run env JIRA_URL="https://x.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing config. Run: jira-task --config"* ]]
}

@test "exits with auth error on 401" {
  setup_mock_curl "401"
  run env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"Authentication failed. Check your email and API token"* ]]
}

@test "exits with auth error on 403" {
  setup_mock_curl "403"
  run env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"Authentication failed. Check your email and API token"* ]]
}

@test "exits with not found error on 404" {
  setup_mock_curl "404"
  run env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"Issue PROJ-123 not found"* ]]
}
