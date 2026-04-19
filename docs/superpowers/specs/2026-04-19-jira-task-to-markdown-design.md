# Jira Task to Markdown — Design

**Date:** 2026-04-19

## Overview

A standalone bash script (`jira-task`) that fetches a Jira Cloud issue and writes it to a `.md` file in the current working directory. Intended to give agentic AI tools context on what to do.

## Project Structure

```
jira-task-to-markdown/
├── jira-task      # executable bash script
└── install.sh     # copies jira-task to ~/bin/ and sets chmod +x
```

## CLI Interface

```bash
jira-task --config       # interactive setup wizard
jira-task PROJ-123       # fetch ticket, write PROJ-123.md to CWD
```

## Configuration

Credentials are stored as environment variables in `~/.zshrc`:

```bash
export JIRA_URL="https://yourcompany.atlassian.net"
export JIRA_EMAIL="you@example.com"
export JIRA_API_TOKEN="your_token_here"
```

**`--config` flow:**
1. Prompt for Jira URL, email, and API token (with hint linking to Atlassian API token page)
2. For each variable: if it already exists in `~/.zshrc`, replace the line; otherwise append it
3. Remind user to run `source ~/.zshrc` to apply

**Main mode:** reads `$JIRA_URL`, `$JIRA_EMAIL`, `$JIRA_API_TOKEN` from environment. If any are missing, exits with: `"Missing config. Run: jira-task --config"`

## API Call

Jira Cloud REST API v3:

```
GET $JIRA_URL/rest/api/3/issue/{ISSUE_KEY}
Authorization: Basic base64(email:api_token)
Accept: application/json
```

Fields used from response: `fields.summary`, `fields.description`.

## ADF → Markdown Extraction

The `description` field returns as **Atlassian Document Format (ADF)** JSON. `jq` walks the tree recursively to produce Markdown:

| ADF node type | Rendered as |
|---|---|
| `paragraph` | text + blank line |
| `heading` | `#` to `######` |
| `bulletList` / `listItem` | `- item` |
| `orderedList` / `listItem` | `1. item` |
| `codeBlock` | fenced ` ``` ` block |
| `hardBreak` | newline |
| `text` | plain text (bold/italic marks preserved) |

If description is null or empty, the Description section is omitted.

## Output Format

File is named `{ISSUE_KEY}.md` and saved in the current working directory:

```markdown
# PROJ-123: Summary title here

## Description

Full description text here, converted from ADF to markdown.

- bullet points preserved
- headings preserved
```

## Error Handling

| Scenario | Behaviour |
|---|---|
| Missing env vars | Exit: "Missing config. Run: jira-task --config" |
| Issue not found (404) | Exit: "Issue PROJ-123 not found" |
| Auth failure (401/403) | Exit: "Authentication failed. Check your email and API token" |
| `jq` not installed | Exit: "jq is required. Install with: brew install jq" |
| Empty description | Omit Description section |
| curl failure | Exit with curl error message |

## Dependencies

- `curl` (pre-installed on macOS)
- `jq` (`brew install jq`)
- `base64` (pre-installed on macOS)
