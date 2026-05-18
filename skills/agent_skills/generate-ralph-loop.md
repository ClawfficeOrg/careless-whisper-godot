# Skill: Generate a Ralph Loop for Any Project

You are an expert agent workflow architect. When a user asks you to "build a ralph loop",
"set up an autonomous task agent", or similar, follow this skill to produce a complete,
working ralph loop tailored to their specific project.

A **ralph loop** is an autonomous task-agent loop that:
- Works through a prioritised task list one item at a time
- Plans with a cheap/fast model, implements with a capable/expensive model
- Reviews its own work after every task
- Runs checks/lint and retries on failure
- Commits and pushes each task on its own branch
- Logs everything (full transcript + milestone summary) to files
- Tracks API usage cost (tokens, requests, or budget — whichever the provider exposes)
- Stops gracefully on SIGTERM, SIGINT, a `STOP.md` sentinel file, a time limit, or a task count limit

---

## Phase 0 — Understand the Project

Before writing a single line, gather the following by reading the repo and asking the
user if anything is unclear:

1. **Project type** — language, framework, build system (e.g. Rust/Cargo, Node/npm,
   Python/uv, GDScript/Godot, Go, etc.)
2. **Lint / check commands** — what must pass before a commit is allowed?
3. **Task list file** — where tasks live (e.g. `docs/plan.md`, `todo.md`, `TASKS.md`).
   If none exists, note that ralph will auto-generate one.
4. **Base directory** — the repo root (used for all relative paths).
5. **AI CLI tool** — which CLI agent is available? See §Provider Matrix below.
6. **Cheap model** — for planning, review, commit messages, doc writing.
7. **Capable/expensive model** — for all code, tests, and implementation.
8. **Cost metric** — how does the user want to track spend? See §Cost Tracking below.
9. **Branch strategy** — does the project use a trunk branch (`main`, `master`, `dev`)?
10. **Stop sentinel path** — where to drop `STOP.md` (default: `ralph/STOP.md`).

---

## Phase 1 — Choose the AI CLI Tool

The shell script must invoke an AI agent CLI. Choose based on what is installed and
authenticated in the project environment:

### Provider Matrix

| CLI | Install check | Non-interactive invocation | Model flag | Notes |
|-----|--------------|---------------------------|------------|-------|
| **Claude Code** (`claude`) | `claude --version` | `claude -p "PROMPT" --model MODEL --dangerously-skip-permissions` | `--model claude-sonnet-4-6` or `--model claude-haiku-4-5` | Anthropic subscription or API key. `-p` = print mode (non-interactive). `--dangerously-skip-permissions` bypasses confirmation prompts for unattended use. Output goes to stdout. |
| **GitHub Copilot CLI** (`copilot`) | `copilot --version` | `copilot -p "PROMPT" --model MODEL --allow-all --no-ask-user --add-dir DIR` | `--model gpt-5-mini` or `--model claude-sonnet-4.6` | Requires `gh auth login` + Copilot subscription. `-s` flag silences streaming for cheap calls. |
| **Aider** (`aider`) | `aider --version` | `aider --message "PROMPT" --model MODEL --yes --no-check-update` | `--model gpt-4o-mini` or `--model claude-opus-4-5` | Open-source. Works with OpenAI, Anthropic, etc. API keys via env vars. |
| **OpenAI Codex CLI** (`codex`) | `codex --version` | `codex -q "PROMPT" --model MODEL --non-interactive` | `--model gpt-4o-mini` or `--model gpt-4o` | OpenAI API key via `OPENAI_API_KEY`. |
| **Gemini CLI** (`gemini`) | `gemini --version` | `gemini -p "PROMPT" --model MODEL --non-interactive` | `--model gemini-2.5-flash` or `--model gemini-2.5-pro` | Google AI Studio or Vertex. |
| **Amp** (`amp`) | `amp --version` | `amp run "PROMPT" --model MODEL --yes` | `--model claude-sonnet-4-6` | Amp.dev agent. |

**Selection logic (in order):**
1. If the user specifies a CLI, use it.
2. Otherwise detect what is installed and authenticated:
   - `claude --version 2>/dev/null` → use Claude Code
   - `copilot --version 2>/dev/null` → use GitHub Copilot CLI
   - `aider --version 2>/dev/null` → use Aider
   - `codex --version 2>/dev/null` → use OpenAI Codex CLI
3. If none found, emit a clear `die` message listing install options.

The `ralph.sh` sanity check section must test for the chosen CLI and die helpfully if
it is missing.

---

## Phase 2 — Choose the Model Pair

### Cheap model (planning, review, docs, commit messages)
Used for all non-code work. Must be fast and low-cost.

| Provider | Recommended cheap model |
|----------|------------------------|
| Anthropic (Claude Code / Copilot) | `claude-haiku-4-5` or `gpt-5-mini` |
| OpenAI (Codex / Copilot) | `gpt-4o-mini` or `gpt-5-mini` |
| Google | `gemini-2.5-flash` |
| Local / Ollama | `llama3.2:3b` or similar small model |

### Capable model (all code, tests, implementation)
Used only when writing or fixing code. Higher cost but higher quality.

| Provider | Recommended capable model |
|----------|--------------------------|
| Anthropic | `claude-sonnet-4-6` or `claude-opus-4-5` |
| OpenAI | `gpt-4o` or `codex-1` |
| Google | `gemini-2.5-pro` |
| Local / Ollama | `qwen2.5-coder:32b` or `deepseek-coder-v2` |

The user should confirm the model pair before proceeding. Record the final choice in
the generated `ralph.sh` as `CHEAP_MODEL` and `CODE_MODEL` variables.

---

## Phase 3 — Cost / Usage Tracking

Different providers expose usage differently. The script must track whatever is
measurable and log it at every task completion and session end.

### Tracking modes

| Mode | When to use | What to track |
|------|-------------|---------------|
| **Invocation count** | Always available | Count every `CHEAP_MODEL` call (`CHEAP_CALLS`) and every `CODE_MODEL` call (`CODE_CALLS`) separately. Both totals logged at session end. |
| **Dollar budget** | Claude Code with `--max-budget-usd` | Pass `--max-budget-usd N` to each `claude -p` call. Read remaining budget from exit status or output. Log estimated spend. |
| **Token estimate** | All providers | Rough estimate: cheap call ≈ 50 K tokens, code call ≈ 200 K tokens. Track `ESTIMATED_TOKENS` as running total. Useful for rate-limit awareness. |
| **Output parsing** | Claude Code / Aider verbose mode | Some CLIs print token usage in verbose output. Capture stderr to log; grep for token counts. |

**Recommended default:** Track invocation counts for both models. Always increment
`CODE_CALLS` before every capable-model invocation (these are expensive). Log at
every task boundary:

```sh
# In summary log:
# COST | task-N done | cheap_calls: 3 | code_calls: 2 | est_tokens: ~500K
```

If the user wants dollar tracking and is using Claude Code, also pass
`--max-budget-usd` and log the value. The `--max-budget-usd` flag causes Claude Code
to refuse to run when the budget would be exceeded, acting as an automatic cost
circuit-breaker.

---

## Phase 4 — Write the Files

Generate three files. Adapt all project-specific details (language, build commands,
paths) but keep the overall structure identical to what is described here.

---

### File A: `skills/ralph.md` (the agent skill / system prompt)

This is the markdown document passed to the AI agent at each step. It must contain:

**Sections (in order):**
1. **Identity and ground rules** — who ralph is, what he must never do (no
   `--no-verify`, no commits with failing checks, no scope creep, no destructive
   commands).
2. **Startup checklist** — read project docs, check git status, create task branch.
   If `docs/plan.md` / `todo.md` doesn't exist, create it from README + status docs.
3. **Implementation loop** (5 steps):
   - Research (cheap model, read-only)
   - Plan (cheap model, numbered list of files/changes/tests, no code)
   - Implement (capable model, write all code, run checks)
   - Self-review checklist (cheap model, PASS/FAIL each item, fix FAILs)
   - Lint/checks (up to 3 attempts with capable-model fixes on failure)
   - Commit and push
4. **Language/framework-specific rules** — a quick-reference table of the most
   important coding rules for this project (extracted from AGENTS.md, CLAUDE.md, or
   equivalent). Examples: type annotations, naming conventions, no debug prints.
5. **Self-review checklist** — 15–25 items covering correctness, style, architecture,
   and hygiene. All items must have a PASS/FAIL answer.
6. **What to do when stuck** — BLOCKED procedure, log entry, branch cleanup.
7. **Task priority order** — work through tasks in `docs/plan.md` order. Note any
   tasks that require human review before running (e.g. CI/CD secrets, destructive
   migrations).
8. **Model usage policy table** — which model for which work type.
9. **Cost tracking notes** — what `CODE_CALLS` means, how it is logged.
10. **Stop conditions** — list all five stop conditions.
11. **Logging conventions** — describe both log files, milestone event names.

Keep it concise. Use tables and checklists. Target 200–350 lines.

---

### File B: `scripts/ralph.sh` (the orchestration shell script)

Must be POSIX `/bin/sh` compatible. Use `set -e` at the top.

**Required sections in order:**

#### 1. Header comment block
```sh
#!/bin/sh
# ralph — autonomous task loop for <PROJECT NAME>.
#
# Usage:
#   ./scripts/ralph.sh                         # loop until no open tasks
#   ./scripts/ralph.sh task-3                  # single task
#   ./scripts/ralph.sh --minutes=30            # time-bounded loop
#   ./scripts/ralph.sh --hours=2               # time-bounded loop
#   ./scripts/ralph.sh --tasks=5               # task-count-bounded loop
#   ./scripts/ralph.sh --bg                    # background mode (log only, no console)
#   # flags may be combined; whichever limit hits first stops the loop
#
# Stopping gracefully (current task finishes first):
#   touch ralph/STOP.md
#   kill -TERM $(cat /tmp/ralph-<project>.pid)
#   Ctrl-C
```

#### 2. Configuration variables
```sh
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/skills/ralph.md"
LOG_DIR="$REPO_ROOT/ralph/logs"
RALPH_DIR="$REPO_ROOT/ralph"
STOP_SENTINEL="$RALPH_DIR/STOP.md"
PID_FILE="/tmp/ralph-<project-slug>.pid"
CHEAP_MODEL="<cheap model>"
CODE_MODEL="<capable model>"
BASE_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
```

#### 3. Colour helpers (tput, guarded with `|| true`)
`log()`, `good()`, `warn()`, `die()` — cyan/green/yellow/red prefixed output.

#### 4. Argument parser
Parse `--minutes=N`, `--hours=N`, `--tasks=N`, `--bg`, and a single positional
task ID. Compute `DEADLINE` (epoch seconds, 0 = none) and `TASK_LIMIT` (0 = none).
Unknown flags: `die "Unknown flag: $_arg"`.

#### 5. Sanity checks
- `[ -f "$SKILL" ] || die "skill file missing: $SKILL"`
- `command -v <cli> >/dev/null 2>&1 || die "<cli> not found — install with: <install command>"`
- Check git clean working tree.

#### 6. PID file + signal traps
- Write PID to `$PID_FILE`.
- `trap 'rm -f "$PID_FILE"' EXIT`
- `trap 'STOP_REQUESTED=1; warn "Stop signal received"' INT TERM`

#### 7. Session timestamp + log file creation
```sh
SESSION_TS="$(date '+%Y%m%d-%H%M%S')"
FULL_LOG="$LOG_DIR/ralph-${SESSION_TS}.log"
SUMMARY_LOG="$LOG_DIR/ralph-summary-${SESSION_TS}.log"
mkdir -p "$LOG_DIR"
```

#### 8. Dual-logging helpers
```sh
# _tee: pipe output to full log; also print to console unless --bg
_tee() { if [ "$BG_MODE" = "1" ]; then cat >> "$FULL_LOG"; else tee -a "$FULL_LOG"; fi; }

# _summary: write a milestone entry to both logs
_summary() {
  ENTRY="[SUMMARY] $*"
  printf '%s\n' "$ENTRY" >> "$FULL_LOG"
  printf '## %s  %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$SUMMARY_LOG"
}
```

#### 9. Usage counter helpers
```sh
CHEAP_CALLS=0
CODE_CALLS=0
ESTIMATED_TOKENS=0

_cheap_call() {
  CHEAP_CALLS=$((CHEAP_CALLS + 1))
  ESTIMATED_TOKENS=$((ESTIMATED_TOKENS + 50000))
  log "  [cheap call #${CHEAP_CALLS}] ${CHEAP_MODEL}"
  # invoke cheap model here; output piped through _tee
}

_code_call() {
  CODE_CALLS=$((CODE_CALLS + 1))
  ESTIMATED_TOKENS=$((ESTIMATED_TOKENS + 200000))
  log "  [code call #${CODE_CALLS}] ${CODE_MODEL}"
  # invoke capable model here; output piped through _tee
}
```

Adapt token estimates to the typical context size of the chosen CLI.

If the user wants dollar-budget tracking with Claude Code:
```sh
MAX_BUDGET_USD="${RALPH_MAX_BUDGET_USD:-}"   # set via env var
_budget_flag() {
  if [ -n "$MAX_BUDGET_USD" ]; then printf ' --max-budget-usd %s' "$MAX_BUDGET_USD"; fi
}
```
And append `$(_budget_flag)` to every `claude -p` invocation.

#### 10. Stop condition helpers
```sh
deadline_reached() { [ "$DEADLINE" -gt 0 ] && [ "$(date +%s)" -ge "$DEADLINE" ]; }
task_limit_reached() { [ "$TASK_LIMIT" -gt 0 ] && [ "$TASKS_DONE" -ge "$TASK_LIMIT" ]; }
stop_requested() {
  [ "$STOP_REQUESTED" -eq 1 ] && return 0
  if [ -f "$STOP_SENTINEL" ]; then
    warn "Stop sentinel found: $STOP_SENTINEL — consuming it."
    rm -f "$STOP_SENTINEL"
    STOP_REQUESTED=1; return 0
  fi
  return 1
}
```

#### 11. Task discovery helpers
```sh
next_task() {
  grep -m1 "^\- \[ \]" "$REPO_ROOT/docs/plan.md" \
    | sed 's/.*`\([^`]*\)`.*/\1/' || true
}
task_block() {
  TASK_ID="$1"
  awk -v tid="$TASK_ID" '
    BEGIN { pat = "^- \\[.\\] `" tid "`" }
    $0 ~ pat { found=1; print; next }
    found && /^- \[.\] `/ { exit }
    found { print }
  ' "$REPO_ROOT/docs/plan.md"
}
mark_task_done() {
  TASK_ID="$1"
  TMPFILE="$(mktemp)"
  sed "s/^- \[ \] \`${TASK_ID}\`/- [x] \`${TASK_ID}\`/" \
    "$REPO_ROOT/docs/plan.md" > "$TMPFILE"
  mv "$TMPFILE" "$REPO_ROOT/docs/plan.md"
}
```

#### 12. `ensure_plan()` function
If `docs/plan.md` doesn't exist, use the cheap model to generate a task list from
`README.md` + status/changelog docs. Write it to `docs/plan.md`. Log a summary entry.

#### 13. `run_checks()` function
Runs the project's lint/check commands. Returns non-zero on failure.
Adapt to the project's toolchain:
- Rust: `cargo fmt --check && cargo clippy … && cargo test …`
- Node: `npm run lint && npm test`
- Python: `ruff check . && pytest`
- GDScript/Godot: `./scripts/lint.sh --strict`
- Go: `gofmt -l . && go vet ./… && go test ./…`

#### 14. `ralph_log()` helper
Appends a timestamped entry to `docs/ralph-log.md`.

#### 15. `run_task()` function — the 5-step per-task runner
```
Step 1/5 — Plan (cheap model)
Step 2/5 — Implement (capable model)
Step 3/5 — Self-review (cheap model)
Step 4/5 — Checks (run_checks, up to 3 fix attempts with capable model)
Step 5/5 — Commit and push
```

After the commit:
- Call `mark_task_done TASK_ID`
- Emit a `_summary "TASK DONE | $TASK_ID | elapsed: Xs | cheap_calls: N | code_calls: N | est_tokens: ~Nk"` entry.
- Call `ralph_log "DONE: $TASK_ID …"`

#### 16. Main loop
Single-task mode and loop mode. Before each task check all stop conditions.
At session end emit a `SESSION END` summary line with totals.

---

### File C: `docs/plan.md` (initial task list)

Create this only if the project does not already have a task file. Generate a
task list by reading `README.md`, `STATUS.md` (or `CHANGELOG.md`), and any existing
`AGENTS.md` / `CLAUDE.md`. Format:

```markdown
# <Project Name> — Task Plan

_Generated: YYYY-MM-DD_

Tasks are ordered by dependency. Each is a single focused unit of work.

- [ ] `task-1`: <description>
- [ ] `task-2`: <description>
…
```

Aim for 10–20 tasks. The last task should be something that requires human review
(CI setup, production deploy, secrets) and note it in the skill file.

---

## Phase 5 — Supporting Files

Also create or update these files as needed:

| File | Content |
|------|---------|
| `ralph/.gitkeep` | Brief README: what the `ralph/` dir is for, how to stop ralph |
| `.gitignore` entry | Add `ralph/logs/` so transcripts are never committed |
| `docs/ralph-log.md` | Empty stub with `# Ralph Log` header, latest-first entries |

---

## Phase 6 — Validation Checklist

Before delivering the output, verify:

- [ ] `sh -n scripts/ralph.sh` passes (POSIX syntax check)
- [ ] All tput calls are guarded with `|| true`
- [ ] `CHEAP_CALLS` and `CODE_CALLS` are incremented before every AI invocation
- [ ] `_summary` is called at: session start, each task start, plan ready, impl done,
      review done, checks pass/fail, commit, task done, session end
- [ ] `ensure_plan` is called before the main loop
- [ ] `mark_task_done` is called after every successful commit
- [ ] The stop sentinel path matches `STOP_SENTINEL` in the script
- [ ] PID file path is unique to this project (no collision with other ralph instances)
- [ ] `run_checks()` uses the correct commands for this project's toolchain
- [ ] The skill file references the correct lint command
- [ ] `docs/plan.md` uses the exact format `- [ ] \`task-N\`: description`
- [ ] A `.gitignore` entry for `ralph/logs/` exists or is mentioned

---

## Example Invocations to Include in ralph.sh Header

Always include these examples, adapted for the project:

```sh
# Run up to 3 tasks with a 2-hour time cap:
./scripts/ralph.sh --hours=2 --tasks=3

# Run overnight unattended (log only, no console):
./scripts/ralph.sh --bg --hours=8

# Run a single specific task:
./scripts/ralph.sh task-1

# Stop ralph mid-session:
touch ralph/STOP.md
# or:
kill -TERM $(cat /tmp/ralph-<project>.pid)
```

---

## Notes on Adapting Across Project Types

| Concern | Guidance |
|---------|----------|
| **No pre-commit hook** | The script should still run `run_checks()` before committing. If the project has a pre-commit hook, rely on it; if not, enforce checks manually. |
| **Monorepo** | Set `--add-dir` (Claude Code) or `--add-dir` (Copilot) to the specific package subdirectory. Scope lint commands to that subtree. |
| **Windows** | The script is POSIX sh; run it from Git Bash or WSL. Note this in the header. `tput` may not be available in Git Bash — all `tput` calls must be guarded. |
| **No internet in CI** | Add a `--offline` flag stub that disables model calls and just runs checks. |
| **Multiple AI providers** | If the user has both Claude Code and an OpenAI key, suggest using Claude Code for the capable model and the OpenAI key (via Aider or the OpenAI CLI) for the cheap model to minimise Anthropic subscription usage. |
| **Local models (Ollama etc.)** | The invocation pattern is the same; just swap model names. Token estimates should be set to 0 (local = free). Track `CODE_CALLS` for quality-assurance purposes only. |
| **Rate limits** | Add a `sleep 5` between tasks in the main loop (configurable via `RALPH_TASK_SLEEP` env var). For Copilot's known rate limits, add `sleep 30` between code calls. |
