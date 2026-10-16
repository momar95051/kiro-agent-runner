# kiro-agent-runner

Run long-duration autonomous AI jobs on any project — a **worker** Claude Code instance works unattended in tmux while a **watcher** checks on it periodically and nudges it when stuck.

Inspired by Laith Al-Saadoon's *"Claude Code watching Claude Code over tmux"* (October 2026).

```
worker (Claude Code in tmux)          watcher (Claude Code on timer)
┌─────────────────────────┐           ┌──────────────────────────────┐
│ /goal See brief.md ...  │           │ reads screen via              │
│                         │ ◄─────── │ tmux capture-pane             │
│ [working autonomously]  │           │                               │
│                         │ ──────── ► state.md: "in progress"       │
│ merges PRs, writes      │           │                               │
│ files, runs tests ...   │           │ ACTION: sleep (worker busy)   │
└─────────────────────────┘           └──────────────────────────────┘
```

## Install

```zsh
git clone https://github.com/<you>/kiro-agent-runner.git
cd kiro-agent-runner
./install.sh
source ~/.zshrc
kiro-init        # set up your profile once
```

## Use

```zsh
cd ~/projects/myapp
kiro-job my-feature           # scaffolds brief if needed, then launches
```

Or step by step:
```zsh
kiro-brief my-feature         # interactive interview → brief.md
kiro-job   my-feature 60      # launch, check every 60 min
```

## Commands

| Command | Purpose |
|---|---|
| `kiro-init` | One-time profile setup (long-term memory) |
| `kiro-brief <name> [dir]` | Interactive scaffolding → writes brief.md |
| `kiro-job <name> [dir] [interval]` | Launch worker + watcher |
| `kiro-watcher <job_dir> <session> [interval]` | Watcher only |
| `kiro-watch` | Live activity feed |

## Memory

- **Long-term** (`~/.kiro-runner/memory/`) — your profile, preferences, learnings across all jobs
- **Short-term** (`<project>/.kiro/jobs/<name>/`) — brief, state, decisions for one job

## Docs

- [Architecture](docs/ARCHITECTURE.md) — full design, data flow, component breakdown
- [Usage](docs/USAGE.md) — day-to-day guide, troubleshooting

## Requirements

- macOS or Linux
- tmux ≥ 2.6
- Claude Code CLI (`claude`)
- python3, git
- Kiro IDE (optional — enables activity logging)
