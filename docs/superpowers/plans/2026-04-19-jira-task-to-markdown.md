# Jira Task to Markdown — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single bash script (`jira-task`) that fetches a Jira Cloud issue via REST API v3 and writes it to a `.md` file in the current directory, with an interactive `--config` command to store credentials in `~/.zshrc`.

**Architecture:** Single executable bash script with two modes: `--config` writes three env vars to `~/.zshrc`; `ISSUE-KEY` calls the Jira Cloud REST API, converts the ADF description to Markdown via a recursive `jq` function, and writes `ISSUE-KEY.md` to the current directory.

**Tech Stack:** bash, curl (pre-installed on macOS), jq (`brew install jq`), bats-core (`brew install bats-core`) for testing.

---

## File Map

| File | Purpose |
|---|---|
| `jira-task` | Executable bash script — two modes: `--config` and `ISSUE-KEY` |
| `install.sh` | Copies `jira-task` to `~/bin/` and sets executable bit |
| `tests/test_jira_task.bats` | bats test suite |
| `.gitignore` | Ignores `.DS_Store` |

---

### Task 1: Project scaffold

**Files:**
- Create: `jira-task`
- Create: `install.sh`
- Create: `tests/test_jira_task.bats`
- Create: `.gitignore`

- [ ] **Step 1: Install test framework**

```bash
brew install bats-core
bats --version
```

Expected: prints `Bats 1.x.x`

- [ ] **Step 2: Initialise git repo**

```bash
cd /Users/jason/Documents/Projects/Personal/jira-task-to-markdown
git init
```

- [ ] **Step 3: Create jira-task stub**

Create `jira-task`:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- [ ] **Step 4: Create install.sh stub**

Create `install.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- [ ] **Step 5: Create test file with setup**

Create `tests/test_jira_task.bats`:

```bash
#!/usr/bin/env bats

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/jira-task"

setup() {
  TEST_DIR="$BATS_TEST_TMPDIR"
  mkdir -p "$TEST_DIR/bin"
  export JIRA_TASK_ZSHRC="$TEST_DIR/.zshrc"
}
```

- [ ] **Step 6: Make scripts executable**

```bash
chmod +x jira-task install.sh
```

- [ ] **Step 7: Verify bats finds the test file**

```bash
bats tests/test_jira_task.bats
```

Expected: `0 tests, 0 failures`

- [ ] **Step 8: Create .gitignore and commit**

Create `.gitignore`:

```
.DS_Store
```

```bash
git add jira-task install.sh tests/test_jira_task.bats .gitignore
git commit -m "chore: initial project scaffold"
```

---

### Task 2: Dependency check

**Files:**
- Modify: `tests/test_jira_task.bats`
- Modify: `jira-task`

- [ ] **Step 1: Write failing test**

Add to `tests/test_jira_task.bats`:

```bash
@test "exits with error if jq is not installed" {
  run env PATH="$TEST_DIR/bin" bash "$SCRIPT" PROJ-123
  [ "$status" -eq 1 ]
  [[ "$output" == *"jq is required. Install with: brew install jq"* ]]
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bats tests/test_jira_task.bats
```

Expected: FAIL — script exits 0 with no output

- [ ] **Step 3: Implement dependency check**

Replace the contents of `jira-task`:

```bash
#!/usr/bin/env bash
set -euo pipefail

JIRA_TASK_ZSHRC="${JIRA_TASK_ZSHRC:-$HOME/.zshrc}"

check_dependencies() {
  if ! command -v jq &>/dev/null; then
    echo "jq is required. Install with: brew install jq" >&2
    exit 1
  fi
}

usage() {
  echo "Usage: jira-task --config | ISSUE-KEY" >&2
  exit 1
}

check_dependencies

case "${1:-}" in
  --config) echo "config not yet implemented" ;;
  "") usage ;;
  *) echo "fetch not yet implemented" ;;
esac
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bats tests/test_jira_task.bats
```

Expected: 1 test, 0 failures

- [ ] **Step 5: Commit**

```bash
git add jira-task tests/test_jira_task.bats
git commit -m "feat: add jq dependency check"
```

---

### Task 3: --config command

**Files:**
- Modify: `tests/test_jira_task.bats`
- Modify: `jira-task`

- [ ] **Step 1: Write failing tests**

Add to `tests/test_jira_task.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bats tests/test_jira_task.bats
```

Expected: 4 new tests fail

- [ ] **Step 3: Implement config function**

Replace the contents of `jira-task`:

```bash
#!/usr/bin/env bash
set -euo pipefail

JIRA_TASK_ZSHRC="${JIRA_TASK_ZSHRC:-$HOME/.zshrc}"

check_dependencies() {
  if ! command -v jq &>/dev/null; then
    echo "jq is required. Install with: brew install jq" >&2
    exit 1
  fi
}

usage() {
  echo "Usage: jira-task --config | ISSUE-KEY" >&2
  exit 1
}

set_zshrc_var() {
  local key="$1"
  local value="$2"
  if grep -q "^export ${key}=" "$JIRA_TASK_ZSHRC" 2>/dev/null; then
    sed -i '' "s|^export ${key}=.*|export ${key}=\"${value}\"|" "$JIRA_TASK_ZSHRC"
  else
    printf 'export %s="%s"\n' "$key" "$value" >> "$JIRA_TASK_ZSHRC"
  fi
}

config() {
  echo "Jira Task to Markdown — Configuration"
  echo "Get your API token at: https://id.atlassian.com/manage-profile/security/api-tokens"
  echo ""
  read -r -p "Jira base URL (e.g. https://yourcompany.atlassian.net): " jira_url
  read -r -p "Jira email: " jira_email
  read -r -s -p "Jira API token: " jira_token
  echo ""
  set_zshrc_var "JIRA_URL" "$jira_url"
  set_zshrc_var "JIRA_EMAIL" "$jira_email"
  set_zshrc_var "JIRA_API_TOKEN" "$jira_token"
  echo ""
  echo "Config saved. Run: source $JIRA_TASK_ZSHRC"
}

check_dependencies

case "${1:-}" in
  --config) config ;;
  "") usage ;;
  *) echo "fetch not yet implemented" ;;
esac
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/test_jira_task.bats
```

Expected: 5 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add jira-task tests/test_jira_task.bats
git commit -m "feat: add --config command"
```

---

### Task 4: Env var validation

**Files:**
- Modify: `tests/test_jira_task.bats`
- Modify: `jira-task`

- [ ] **Step 1: Write failing tests**

Add to `tests/test_jira_task.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bats tests/test_jira_task.bats
```

Expected: 3 new tests fail

- [ ] **Step 3: Add fetch_issue stub with validation**

Add the `fetch_issue` function to `jira-task` and update the `case` block. Replace the entire file:

```bash
#!/usr/bin/env bash
set -euo pipefail

JIRA_TASK_ZSHRC="${JIRA_TASK_ZSHRC:-$HOME/.zshrc}"

check_dependencies() {
  if ! command -v jq &>/dev/null; then
    echo "jq is required. Install with: brew install jq" >&2
    exit 1
  fi
}

usage() {
  echo "Usage: jira-task --config | ISSUE-KEY" >&2
  exit 1
}

set_zshrc_var() {
  local key="$1"
  local value="$2"
  if grep -q "^export ${key}=" "$JIRA_TASK_ZSHRC" 2>/dev/null; then
    sed -i '' "s|^export ${key}=.*|export ${key}=\"${value}\"|" "$JIRA_TASK_ZSHRC"
  else
    printf 'export %s="%s"\n' "$key" "$value" >> "$JIRA_TASK_ZSHRC"
  fi
}

config() {
  echo "Jira Task to Markdown — Configuration"
  echo "Get your API token at: https://id.atlassian.com/manage-profile/security/api-tokens"
  echo ""
  read -r -p "Jira base URL (e.g. https://yourcompany.atlassian.net): " jira_url
  read -r -p "Jira email: " jira_email
  read -r -s -p "Jira API token: " jira_token
  echo ""
  set_zshrc_var "JIRA_URL" "$jira_url"
  set_zshrc_var "JIRA_EMAIL" "$jira_email"
  set_zshrc_var "JIRA_API_TOKEN" "$jira_token"
  echo ""
  echo "Config saved. Run: source $JIRA_TASK_ZSHRC"
}

fetch_issue() {
  local issue_key="$1"
  if [[ -z "${JIRA_URL:-}" ]] || [[ -z "${JIRA_EMAIL:-}" ]] || [[ -z "${JIRA_API_TOKEN:-}" ]]; then
    echo "Missing config. Run: jira-task --config" >&2
    exit 1
  fi
  echo "fetch not yet complete"
}

check_dependencies

case "${1:-}" in
  --config) config ;;
  "") usage ;;
  *) fetch_issue "$1" ;;
esac
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/test_jira_task.bats
```

Expected: 8 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add jira-task tests/test_jira_task.bats
git commit -m "feat: add env var validation"
```

---

### Task 5: HTTP error handling

**Files:**
- Modify: `tests/test_jira_task.bats`
- Modify: `jira-task`

- [ ] **Step 1: Add mock curl helper to test file**

Add to `tests/test_jira_task.bats` immediately after the `setup()` block:

```bash
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
```

- [ ] **Step 2: Write failing tests for HTTP errors**

Add to `tests/test_jira_task.bats`:

```bash
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
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
bats tests/test_jira_task.bats
```

Expected: 3 new tests fail

- [ ] **Step 4: Implement API call with HTTP error handling**

Replace the `fetch_issue` function in `jira-task` (all other functions remain unchanged):

```bash
fetch_issue() {
  local issue_key="$1"
  if [[ -z "${JIRA_URL:-}" ]] || [[ -z "${JIRA_EMAIL:-}" ]] || [[ -z "${JIRA_API_TOKEN:-}" ]]; then
    echo "Missing config. Run: jira-task --config" >&2
    exit 1
  fi

  local auth
  auth=$(printf '%s:%s' "${JIRA_EMAIL}" "${JIRA_API_TOKEN}" | base64 | tr -d '\n')

  local tmpfile
  tmpfile=$(mktemp)

  local http_code
  http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" \
    -H "Authorization: Basic ${auth}" \
    -H "Accept: application/json" \
    "${JIRA_URL}/rest/api/3/issue/${issue_key}") || {
    echo "curl failed" >&2
    rm -f "$tmpfile"
    exit 1
  }

  local response
  response=$(cat "$tmpfile")
  rm -f "$tmpfile"

  case "$http_code" in
    200) ;;
    401|403)
      echo "Authentication failed. Check your email and API token" >&2
      exit 1 ;;
    404)
      echo "Issue ${issue_key} not found" >&2
      exit 1 ;;
    *)
      echo "API error: HTTP ${http_code}" >&2
      exit 1 ;;
  esac

  echo "fetch not yet complete"
}
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
bats tests/test_jira_task.bats
```

Expected: 11 tests, 0 failures

- [ ] **Step 6: Commit**

```bash
git add jira-task tests/test_jira_task.bats
git commit -m "feat: add API call with HTTP error handling"
```

---

### Task 6: ADF extraction and output file

**Files:**
- Modify: `tests/test_jira_task.bats`
- Modify: `jira-task`

- [ ] **Step 1: Write failing tests**

Add to `tests/test_jira_task.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bats tests/test_jira_task.bats
```

Expected: 6 new tests fail

- [ ] **Step 3: Complete fetch_issue with ADF extraction and file output**

Replace the `fetch_issue` function in `jira-task` (all other functions remain unchanged):

```bash
fetch_issue() {
  local issue_key="$1"
  if [[ -z "${JIRA_URL:-}" ]] || [[ -z "${JIRA_EMAIL:-}" ]] || [[ -z "${JIRA_API_TOKEN:-}" ]]; then
    echo "Missing config. Run: jira-task --config" >&2
    exit 1
  fi

  local auth
  auth=$(printf '%s:%s' "${JIRA_EMAIL}" "${JIRA_API_TOKEN}" | base64 | tr -d '\n')

  local tmpfile
  tmpfile=$(mktemp)

  local http_code
  http_code=$(curl -s -o "$tmpfile" -w "%{http_code}" \
    -H "Authorization: Basic ${auth}" \
    -H "Accept: application/json" \
    "${JIRA_URL}/rest/api/3/issue/${issue_key}") || {
    echo "curl failed" >&2
    rm -f "$tmpfile"
    exit 1
  }

  local response
  response=$(cat "$tmpfile")
  rm -f "$tmpfile"

  case "$http_code" in
    200) ;;
    401|403)
      echo "Authentication failed. Check your email and API token" >&2
      exit 1 ;;
    404)
      echo "Issue ${issue_key} not found" >&2
      exit 1 ;;
    *)
      echo "API error: HTTP ${http_code}" >&2
      exit 1 ;;
  esac

  local summary
  summary=$(printf '%s' "$response" | jq -r '.fields.summary')

  local description_json
  description_json=$(printf '%s' "$response" | jq -c '.fields.description')

  local description_md=""
  if [[ "$description_json" != "null" ]] && [[ -n "$description_json" ]]; then
    description_md=$(printf '%s' "$description_json" | jq -r '
      def adf_to_md:
        if type == "null" then ""
        elif type == "object" then
          if .type == "doc" then
            (.content // [] | map(adf_to_md) | join(""))
          elif .type == "text" then
            ((.marks // []) | map(.type) | contains(["strong"])) as $bold |
            ((.marks // []) | map(.type) | contains(["em"])) as $em |
            ((.marks // []) | map(.type) | contains(["code"])) as $code |
            (.text // "") |
            if $bold then ("**" + . + "**")
            elif $em then ("_" + . + "_")
            elif $code then ("`" + . + "`")
            else .
            end
          elif .type == "paragraph" then
            ((.content // [] | map(adf_to_md) | join("")) + "\n\n")
          elif .type == "heading" then
            (("#" * (.attrs.level // 1)) + " " + (.content // [] | map(adf_to_md) | join("")) + "\n\n")
          elif .type == "bulletList" then
            (.content // [] | map(adf_to_md) | join(""))
          elif .type == "orderedList" then
            (.content // [] | map(adf_to_md) | join(""))
          elif .type == "listItem" then
            ("- " + ((.content // [] | map(adf_to_md) | join("")) | gsub("\n\n$"; "")) + "\n")
          elif .type == "codeBlock" then
            ("```\n" + (.content // [] | map(adf_to_md) | join("")) + "```\n\n")
          elif .type == "hardBreak" then "\n"
          elif .type == "rule" then "---\n\n"
          elif .type == "inlineCard" then (.attrs.url // "")
          elif .type == "mention" then ("@" + (.attrs.displayName // .attrs.id // "unknown"))
          else (.content // [] | map(adf_to_md) | join(""))
          end
        elif type == "array" then
          map(adf_to_md) | join("")
        else ""
        end;
      adf_to_md
    ')
  fi

  local output_file="${issue_key}.md"
  {
    printf '# %s: %s\n' "$issue_key" "$summary"
    if [[ -n "$description_md" ]]; then
      printf '\n## Description\n\n'
      printf '%s' "$description_md"
    fi
  } > "$output_file"

  echo "Written to ${output_file}"
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bats tests/test_jira_task.bats
```

Expected: 17 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add jira-task tests/test_jira_task.bats
git commit -m "feat: add ADF to markdown conversion and file output"
```

---

### Task 7: install.sh and final verification

**Files:**
- Modify: `install.sh`

- [ ] **Step 1: Implement install.sh**

Replace `install.sh` with:

```bash
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
```

- [ ] **Step 2: Run all tests**

```bash
bats tests/test_jira_task.bats
```

Expected: 17 tests, 0 failures

- [ ] **Step 3: Manually verify install.sh runs without error**

```bash
bash install.sh
```

Expected output:
```
Installed to /Users/<you>/bin/jira-task

Make sure /Users/<you>/bin is in your PATH by adding to ~/.zshrc:
  export PATH="$HOME/bin:$PATH"

Then run: jira-task --config
```

- [ ] **Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add install.sh"
```
