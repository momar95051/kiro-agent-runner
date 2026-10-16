# kiro-agent-runner — Architecture

## Overview

`kiro-agent-runner` is a self-contained toolkit that implements the **Worker + Watcher** autonomous agent pattern using Claude Code and tmux. It gives any AI-assisted project a consistent, portable structure for running long-duration autonomous tasks with human oversight.

The pattern is inspired by Laith Al-Saadoon's article *"Claude Code watching Claude Code over tmux"* (October 2026): a worker Claude Code instance runs a job autonomously inside tmux while a second watcher instance checks on it periodically, reads its screen, and nudges it when stuck.

---

## Mental Model

```
┌─────────────────────────────────────────────────────────┐
│                        YOU                               │
│   (goals, background, preferences, past decisions)       │
└──────────────────┬──────────────────────────────────────┘
                   │
         ┌─────────▼──────────┐
         │   LONG-TERM        │  ~/.kiro-runner/memory/
         │   MEMORY           │  ├── profile.md       who you are
         │                    │  ├── preferences.md   how you work
         │                    │  ├── decisions.md     past choices
         │                    │  └── learnings.md     what worked
         └─────────┬──────────┘
                   │ informs every brief
         ┌─────────▼──────────┐
         │   SHORT-TERM       │  <project>/.kiro/jobs/<name>/
         │   MEMORY           │  ├── brief.md         this job's goal
         │   (per job)        │  ├── state.md         worker status now
         │                    │  ├── decisions.md     mid-job decisions
         │                    │  └── watcher.md       watcher tick memory
         └─────────┬──────────┘
                   │ executes
         ┌─────────▼──────────┐
         │   RUNTIME          │  tmux sessions
         │                    │  ├── worker-<name>    Claude Code worker
         │                    │  └── monitor-<name>   watcher + activity feed
         └────────────────────┘
```

---

## Repository Structure

```
kiro-agent-runner/
│
├── install.sh                  # Bootstrap script — run on a fresh machine
│
├── bin/                        # All user-facing commands (symlinked to ~/bin)
│   ├── kiro-init               # One-time: create long-term memory profile
│   ├── kiro-brief              # Interactive interview → writes brief.md
│   ├── kiro-job                # Launch worker + watcher for a project
│   ├── kiro-watcher            # Watcher loop (Claude reads worker screen)
│   └── kiro-watch              # Live tail of Kiro/Claude tool activity log
│
├── lib/                        # Shared shell functions
│   ├── common.sh               # Logging, colors, path helpers
│   ├── preflight.sh            # Dependency checks + auto-install
│   └── memory.sh               # Read/write long-term memory helpers
│
├── templates/                  # Scaffolding templates
│   ├── brief.md                # Brief template with all required sections
│   ├── state.md                # Initial state file
│   ├── decisions.md            # Empty decisions log
│   └── watcher.md              # Initial watcher memory
│
├── memory/                     # Default long-term memory stubs (copied to ~/.kiro-runner/memory on init)
│   ├── profile.md
│   ├── preferences.md
│   ├── decisions.md
│   └── learnings.md
│
└── docs/
    ├── ARCHITECTURE.md         # This file
    └── USAGE.md                # Day-to-day usage guide
```

---

## Components

### install.sh

Run once on a fresh machine. Does:
1. Checks OS (macOS / Linux)
2. Checks and installs prerequisites: `tmux`, `git`, `claude` CLI, `python3`
3. Symlinks `bin/*` into `~/bin/`
4. Ensures `~/bin` is in `$PATH` (adds to `.zshrc` / `.bashrc`)
5. Creates `~/.kiro-runner/memory/` from `memory/` templates
6. Installs the Kiro PreToolUse hook for activity logging (if Kiro is present)
7. Prints a getting-started summary

### bin/kiro-init

One-time setup of your long-term memory profile. Asks:
- Your name and professional background
- Domains you work in (Healthcare, Pharma, SaaS, etc.)
- Default rules for all jobs (e.g. "never push to main")
- Preferred watcher interval
- Output language preference

Writes to `~/.kiro-runner/memory/profile.md` and `preferences.md`.

### bin/kiro-brief

Interactive scaffolding for a new job. Flow:
1. Loads `profile.md` + `preferences.md` from long-term memory
2. Asks minimal questions: job name, goal (free text), done criteria, constraints
3. Uses Claude (`claude -p`) to synthesize answers + profile into a structured `brief.md`
4. Shows a preview, asks: **ready / refine / cancel**
5. On "refine" loops back with your feedback
6. On "ready" writes the file and prints the launch command

### bin/kiro-job

Main entrypoint. Given a job name and optional project dir:
1. Runs preflight checks
2. If no `brief.md` → delegates to `kiro-brief`
3. Scaffolds `state.md`, `decisions.md`, `watcher.md` from templates if missing
4. Injects long-term memory context into the worker's goal line
5. Launches worker Claude Code in tmux (`worker-<name>`)
6. Launches monitor window in tmux (`monitor-<name>`): watcher left, activity feed right
7. Attaches you to the monitor

### bin/kiro-watcher

Runs on a timer inside the monitor tmux pane. Each tick:
1. Reads worker screen via `tmux capture-pane`
2. Reads `state.md`, `decisions.md`, `brief.md`
3. Sends all context to Claude (`claude -p`) headlessly
4. Parses the response: `sleep | nudge | alert | done`
5. Acts: sends keys, shows macOS notification, or exits
6. On `done`: appends job summary to `~/.kiro-runner/memory/learnings.md`
7. Updates `watcher.md` with tick memory

### bin/kiro-watch

Simple live tail of `~/.kiro-runner/activity.log` with emoji-decorated tool names. Works for both Kiro IDE sessions and Claude Code workers.

---

## Memory System

### Long-term Memory (`~/.kiro-runner/memory/`)

| File | Written by | Read by | Purpose |
|---|---|---|---|
| `profile.md` | `kiro-init`, user | `kiro-brief`, `kiro-job` | Who you are — pre-fills every brief |
| `preferences.md` | `kiro-init`, user | `kiro-brief`, `kiro-job` | Default rules, intervals, output format |
| `decisions.md` | user, `kiro-brief` | `kiro-brief` | Past cross-job decisions — avoids re-asking |
| `learnings.md` | `kiro-watcher` (on done) | `kiro-brief` | What worked, what didn't — improves future briefs |

### Short-term Memory (`<project>/.kiro/jobs/<name>/`)

| File | Written by | Read by | Purpose |
|---|---|---|---|
| `brief.md` | `kiro-brief`, user | worker, watcher | Job definition and done criteria |
| `state.md` | worker | watcher | Current worker status |
| `decisions.md` | user | worker (every turn) | Mid-job human decisions |
| `watcher.md` | watcher | watcher | Tick memory (last commit, last nudge) |

---

## Data Flow

```
kiro-init
  └─→ ~/.kiro-runner/memory/profile.md
  └─→ ~/.kiro-runner/memory/preferences.md

kiro-brief <name>
  ├─← ~/.kiro-runner/memory/profile.md        (pre-fill context)
  ├─← ~/.kiro-runner/memory/preferences.md    (default rules)
  ├─← ~/.kiro-runner/memory/learnings.md      (past job insights)
  ├─→ <project>/.kiro/jobs/<name>/brief.md    (output)
  └─→ ~/.kiro-runner/memory/decisions.md      (record choices made)

kiro-job <name> [project_dir]
  ├─← <project>/.kiro/jobs/<name>/brief.md
  ├─← ~/.kiro-runner/memory/profile.md        (injected into worker goal)
  ├─→ tmux: worker-<name>                     (Claude Code worker)
  └─→ tmux: monitor-<name>                    (kiro-watcher + kiro-watch)

worker (Claude Code in tmux)
  ├─← <project>/.kiro/jobs/<name>/brief.md    (re-reads each turn)
  ├─← <project>/.kiro/jobs/<name>/decisions.md (re-reads each turn)
  └─→ <project>/.kiro/jobs/<name>/state.md    (writes each turn)

kiro-watcher (on timer)
  ├─← tmux capture-pane (worker screen)
  ├─← <project>/.kiro/jobs/<name>/state.md
  ├─← <project>/.kiro/jobs/<name>/brief.md
  ├─← <project>/.kiro/jobs/<name>/decisions.md
  ├─→ tmux send-keys (nudges)
  ├─→ <project>/.kiro/jobs/<name>/watcher.md
  └─→ ~/.kiro-runner/memory/learnings.md      (on job done)
```

---

## Prerequisites

| Tool | Required | Auto-installed by install.sh |
|---|---|---|
| `tmux` | Yes | Yes (brew / apt) |
| `git` | Yes | Yes (brew / apt) |
| `claude` CLI | Yes | Prints install link — requires manual auth |
| `python3` | Yes | Yes (brew / apt) |
| `jq` | Optional | Yes — used for richer transcript parsing |
| Kiro IDE | Optional | No — activity logging hook only installed if present |

---

## Design Principles

1. **Tool-agnostic naming** — files are named by role (`brief`, `state`, `decisions`) not by tool (`claude.md`, `agent.md`)
2. **Location-independent** — all commands work from any project directory; nothing is hardcoded to a specific path
3. **Long-term memory is additive** — the system gets smarter about you over time without requiring manual updates
4. **Human always in the loop** — worker cannot proceed past a `BLOCKED` state without human input; watcher can only nudge, never override
5. **Portable** — one `git clone` + `./install.sh` gets any machine ready
6. **Shell-native** — zsh/bash only, no Node.js, no Python dependencies beyond stdlib
