# Jira to Markdown

Fetches a Jira Cloud issue and writes it to a Markdown file. Intended to give agentic AI tools context on what to work on.

![Jira to Markdown](./images/jira-to-markdown.jpeg) 

## Output

Running `jira-task PROJ-123` creates:

```
PROJ-123/
├── PROJ-123.md       # issue title + description as Markdown
└── images/           # all image attachments, embedded inline in the .md
```

## Installation

```bash
bash install.sh
```

This copies `jira-task` to `~/bin/`. Make sure `~/bin` is in your `PATH`:

```bash
export PATH="$HOME/bin:$PATH"
```

## Setup

```bash
jira-task --config
```

Prompts for your Jira base URL, email, and API token, then saves them to `~/.zshrc`. Get your API token at [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens).

## Usage

```bash
jira-task PROJ-123
```

Image attachments are downloaded with a progress bar:

```
Downloading screenshot.png
######################################################################## 100.0%
```

## Dependencies

- `curl` — pre-installed on macOS
- `jq` — `brew install jq`
