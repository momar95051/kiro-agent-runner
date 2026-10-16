# Usage Guide

## First time on a new machine

```zsh
git clone https://github.com/<you>/kiro-agent-runner.git
cd kiro-agent-runner
./install.sh
source ~/.zshrc

# Set up your profile (once)
kiro-init
```

---

## Running a job

### Quickstart (from any project)

```zsh
cd ~/projects/myapp
kiro-job my-feature
```

If no brief exists, `kiro-job` delegates to `kiro-brief` automatically.

### Step by step

```zsh
# 1. Scaffold a brief interactively
kiro-brief my-feature ~/projects/myapp

# 2. Launch worker + watcher
kiro-job my-feature ~/projects/myapp 60   # check every 60 min
```

### Re-run a job from scratch

```zsh
kiro-job --fresh my-feature ~/projects/myapp 60
```

`--fresh` moves the previous `state.md`, `decisions.md`, `watcher.md` and
`watcher-run.log` to `.kiro/jobs/my-feature/archive/<timestamp>/` and starts from
the templates. `brief.md` is kept. Output files the brief writes are not moved.

Run `kiro-job` from a terminal other than the job's own `worker-*` or `monitor-*`
tmux session: it replaces those sessions, and refuses to run inside one of them.

---

## During a job

### Add a human decision
```zsh
echo "$(date +%Y-%m-%d): try the FHIR approach instead" \
  >> ~/projects/myapp/.kiro/jobs/my-feature/decisions.md
```
The worker re-reads this file every turn. Changes take effect immediately.

### Check worker status
```zsh
cat ~/projects/myapp/.kiro/jobs/my-feature/state.md
```

### Watch live tool activity
```zsh
kiro-watch
```

### Attach to the worker directly
```zsh
tmux attach -t worker-my-feature
# Detach: Ctrl+B then D
```

### Switch between monitor and worker in tmux
```
Ctrl+B then S   → session list
Ctrl+B then %   → split pane vertically
Ctrl+B then ←→  → switch panes
```

---

## Job folder structure

```
<project>/.kiro/jobs/<name>/
  brief.md          ← YOU write: what done looks like
  state.md          ← worker writes: current status
  decisions.md      ← YOU write: mid-job instructions
  watcher.md        ← watcher writes: tick memory
  watcher-run.log   ← watcher log (auto-created)
```

---

## Long-term memory

Lives at `~/.kiro-runner/memory/`. Edit any file directly.

```
~/.kiro-runner/memory/
  profile.md        ← who you are (kiro-init writes this)
  preferences.md    ← default rules + intervals
  decisions.md      ← cross-job decisions
  learnings.md      ← post-job summaries (watcher appends)
```

---

## Brief format reference

```markdown
# Job Brief: <name>

## Background
- Bullet points from your profile relevant to this job

## Goal
1. Done criterion 1
2. Done criterion 2

## Proof Commands
\`\`\`
grep -c "criterion" output/report.md
\`\`\`

## Process
- Step by step approach

## Rules
- Do not push to main
- Cite sources
- Write BLOCKED: <reason> to state.md if stuck

## Output
output/
  report.md
  research/
```

---

## Troubleshooting

**Worker not starting**
```zsh
tmux ls                              # check sessions
tmux attach -t worker-<name>         # see what's happening
```

**Watcher not nudging**
```zsh
cat .kiro/jobs/<name>/watcher-run.log   # check watcher log
```

**Claude CLI not working**
```zsh
claude --version
claude -p "say hello"    # test headless mode
```

**Activity log empty**
- Restart Kiro IDE for the hook to activate
- Check hook exists: `cat .kiro/hooks/agent-activity-logger.json`
