#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/jira-task"

setup() {
  TEST_DIR="$BATS_TEST_TMPDIR"
  mkdir -p "$TEST_DIR/bin"
  export JIRA_TASK_ZSHRC="$TEST_DIR/.zshrc"
}

setup_mock_curl() {
  local status_code="$1"
  local body="${2:-}"
  printf '%s' "$body" > "$TEST_DIR/mock_body.json"
  printf '%s' "$status_code" > "$TEST_DIR/mock_status.txt"

  cat > "$TEST_DIR/bin/curl" << 'CURL_EOF'
#!/usr/bin/env bash
TEST_BIN_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$(dirname "$TEST_BIN_DIR")"
while [ $# -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    cp "$TEST_DIR/mock_body.json" "$2"
    shift 2
  else
    shift
  fi
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

SIMPLE_ISSUE='{"fields":{"summary":"Fix the login bug","description":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Users cannot log in after password reset."}]}]}}}'

@test "creates output file named after issue key" {
  setup_mock_curl "200" "$SIMPLE_ISSUE"
  cd "$TEST_DIR"
  run env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 0 ]
  [ -f "$TEST_DIR/PROJ-123.md" ]
}

@test "output file contains issue key and summary as title" {
  setup_mock_curl "200" "$SIMPLE_ISSUE"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  grep -q "^# PROJ-123: Fix the login bug$" "$TEST_DIR/PROJ-123.md"
}

@test "output file contains description text" {
  setup_mock_curl "200" "$SIMPLE_ISSUE"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-123
  grep -q "Users cannot log in after password reset" "$TEST_DIR/PROJ-123.md"
}

@test "output file omits Description section when description is null" {
  local no_desc='{"fields":{"summary":"Empty issue","description":null}}'
  setup_mock_curl "200" "$no_desc"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-456
  ! grep -q "## Description" "$TEST_DIR/PROJ-456.md"
}

@test "converts ADF heading to markdown heading" {
  local heading_issue='{"fields":{"summary":"Test","description":{"type":"doc","version":1,"content":[{"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Section Title"}]}]}}}'
  setup_mock_curl "200" "$heading_issue"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-789
  grep -q "^## Section Title" "$TEST_DIR/PROJ-789.md"
}

@test "converts ADF bullet list to markdown list" {
  local list_issue='{"fields":{"summary":"Test","description":{"type":"doc","version":1,"content":[{"type":"bulletList","content":[{"type":"listItem","content":[{"type":"paragraph","content":[{"type":"text","text":"Item one"}]}]}]}]}}}'
  setup_mock_curl "200" "$list_issue"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-790
  grep -q "^- Item one" "$TEST_DIR/PROJ-790.md"
}

@test "converts ADF table with tableHeader row to markdown table" {
  local table_issue='{"fields":{"summary":"Test","description":{"type":"doc","version":1,"content":[{"type":"table","content":[{"type":"tableRow","content":[{"type":"tableHeader","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Name"}]}]},{"type":"tableHeader","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Value"}]}]}]},{"type":"tableRow","content":[{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Foo"}]}]},{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Bar"}]}]}]}]}]}}}'
  setup_mock_curl "200" "$table_issue"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-800
  grep -q "^| Name | Value |$" "$TEST_DIR/PROJ-800.md"
  grep -q "^| --- | --- |$" "$TEST_DIR/PROJ-800.md"
  grep -q "^| Foo | Bar |$" "$TEST_DIR/PROJ-800.md"
}

@test "converts ADF table with all tableCell rows treating first row as header" {
  local table_issue='{"fields":{"summary":"Test","description":{"type":"doc","version":1,"content":[{"type":"table","content":[{"type":"tableRow","content":[{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Col A"}]}]},{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Col B"}]}]}]},{"type":"tableRow","content":[{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"1"}]}]},{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"2"}]}]}]}]}]}}}'
  setup_mock_curl "200" "$table_issue"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-801
  grep -q "^| Col A | Col B |$" "$TEST_DIR/PROJ-801.md"
  grep -q "^| --- | --- |$" "$TEST_DIR/PROJ-801.md"
  grep -q "^| 1 | 2 |$" "$TEST_DIR/PROJ-801.md"
}

@test "table cell containing pipe character is escaped" {
  local table_issue='{"fields":{"summary":"Test","description":{"type":"doc","version":1,"content":[{"type":"table","content":[{"type":"tableRow","content":[{"type":"tableHeader","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Command"}]}]},{"type":"tableHeader","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"Notes"}]}]}]},{"type":"tableRow","content":[{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"cat a | grep b"}]}]},{"type":"tableCell","attrs":{},"content":[{"type":"paragraph","content":[{"type":"text","text":"filters"}]}]}]}]}]}}}'
  setup_mock_curl "200" "$table_issue"
  cd "$TEST_DIR"
  env PATH="$TEST_DIR/bin:$PATH" JIRA_URL="https://test.atlassian.net" JIRA_EMAIL="a@b.com" JIRA_API_TOKEN="tok" bash "$SCRIPT" PROJ-802
  grep -q "cat a \\\\| grep b" "$TEST_DIR/PROJ-802.md"
}
