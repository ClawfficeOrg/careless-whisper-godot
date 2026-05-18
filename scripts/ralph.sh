#!/bin/sh
# ralph — autonomous task loop for Careless Whisper (Godot 4.6 speech-recognition app).
#
# Usage:
#   ./scripts/ralph.sh                          # loop until no open tasks remain
#   ./scripts/ralph.sh task-3                   # run a single specific task then stop
#   ./scripts/ralph.sh --minutes=30             # loop for up to 30 minutes
#   ./scripts/ralph.sh --hours=2                # loop for up to 2 hours
#   ./scripts/ralph.sh --hours=1 --minutes=30   # loop for up to 1 h 30 m
#   ./scripts/ralph.sh --tasks=5                # complete at most 5 tasks then stop
#   ./scripts/ralph.sh --bg                     # suppress console output, log only
#   ./scripts/ralph.sh --minutes=45 task-3      # single task, still time-bounded
#   # flags may be combined freely; whichever limit hits first stops the loop
#
# Stopping ralph gracefully (finishes the current task first):
#   touch ralph/STOP.md                          # drop the sentinel file
#   kill -TERM $(cat /tmp/ralph-careless.pid)    # or send SIGTERM
#   Ctrl-C                                       # or SIGINT from the terminal
#
# Log files (created at startup, never deleted by ralph):
#   ralph/logs/ralph-YYYYMMDD-HHMMSS.log         # full transcript
#   ralph/logs/ralph-summary-YYYYMMDD-HHMMSS.log # milestones only (markdown)
#
# NOTE: ralph/logs/ is gitignored (see .gitignore). ralph/STOP.md is NOT
# gitignored so it can be committed as a permanent emergency brake.
#
# Requires: copilot CLI (logged in), git, godot (on PATH for lint), a clean working tree.
# The human has given blanket commit+push permission while this runs.

set -e

# ── paths ────────────────────────────────────────────────────────────────────
REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/skills/ralph.md"
PLAN="$REPO_ROOT/docs/plan.md"
RALPH_DIR="$REPO_ROOT/ralph"
LOG_DIR="$RALPH_DIR/logs"
STOP_SENTINEL="$RALPH_DIR/STOP.md"
RALPH_PID_FILE="/tmp/ralph-careless.pid"

CHEAP_MODEL="gpt-5-mini"
CODE_MODEL="claude-sonnet-4.6"

# The branch ralph was launched from is the trunk to branch off for each task.
BASE_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"

# Timestamp used for both log filenames so they share a session marker.
SESSION_TS="$(date '+%Y%m%d-%H%M%S')"
FULL_LOG="$LOG_DIR/ralph-${SESSION_TS}.log"
SUMMARY_LOG="$LOG_DIR/ralph-summary-${SESSION_TS}.log"

# ── colours ──────────────────────────────────────────────────────────────────
BOLD=$(tput bold 2>/dev/null || true)
CYAN=$(tput setaf 6 2>/dev/null || true)
GREEN=$(tput setaf 2 2>/dev/null || true)
YELLOW=$(tput setaf 3 2>/dev/null || true)
RED=$(tput setaf 1 2>/dev/null || true)
RESET=$(tput sgr0 2>/dev/null || true)

# ── argument parsing ──────────────────────────────────────────────────────────
SINGLE_TASK=""
DURATION_SECS=0
TASK_LIMIT=0
BG_MODE=0

for _arg in "$@"; do
    case "$_arg" in
        --minutes=*)
            _mins="${_arg#--minutes=}"
            case "$_mins" in
                ''|*[!0-9]*) printf '%s\n' "ralph: --minutes requires a positive integer" >&2; exit 1 ;;
            esac
            DURATION_SECS=$((DURATION_SECS + _mins * 60))
            ;;
        --hours=*)
            _hrs="${_arg#--hours=}"
            case "$_hrs" in
                ''|*[!0-9]*) printf '%s\n' "ralph: --hours requires a positive integer" >&2; exit 1 ;;
            esac
            DURATION_SECS=$((DURATION_SECS + _hrs * 3600))
            ;;
        --tasks=*)
            _tl="${_arg#--tasks=}"
            case "$_tl" in
                ''|*[!0-9]*) printf '%s\n' "ralph: --tasks requires a positive integer" >&2; exit 1 ;;
            esac
            TASK_LIMIT="$_tl"
            ;;
        --bg)
            BG_MODE=1
            ;;
        -*)
            printf '%s\n' "ralph: unknown flag: $_arg  (supported: --minutes=N  --hours=N  --tasks=N  --bg)" >&2
            exit 1
            ;;
        *)
            if [ -n "$SINGLE_TASK" ]; then
                printf '%s\n' "ralph: too many positional arguments — only one task id is allowed" >&2
                exit 1
            fi
            SINGLE_TASK="$_arg"
            ;;
    esac
done

# Compute absolute deadline (epoch seconds). 0 = no limit.
START_TIME="$(date +%s)"
if [ "$DURATION_SECS" -gt 0 ]; then
    DEADLINE=$((START_TIME + DURATION_SECS))
else
    DEADLINE=0
fi

# ── logging helpers ───────────────────────────────────────────────────────────
# All output goes through these; --bg suppresses console but always writes logs.

_ts() { date '+%H:%M:%S'; }

# Write a line to both log files.
_log_raw() {
    printf '%s\n' "$1" >> "$FULL_LOG"
}

# Write a [SUMMARY] milestone to both logs.
_summary() {
    _line="$1"
    printf '[SUMMARY] %s  %s\n' "$(_ts)" "$_line" >> "$FULL_LOG"
    printf '%s\n' "$_line" >> "$SUMMARY_LOG"
}

# Console + log helpers.  --bg silences the console variants.
log() {
    _msg="${CYAN}[ralph]${RESET} $*"
    _log_raw "[ralph] $*"
    if [ "$BG_MODE" -eq 0 ]; then printf '%s\n' "$_msg"; fi
}

good() {
    _msg="${GREEN}[ralph]${RESET} $*"
    _log_raw "[GOOD]  $*"
    if [ "$BG_MODE" -eq 0 ]; then printf '%s\n' "$_msg"; fi
}

warn() {
    _msg="${YELLOW}[ralph]${RESET} $*"
    _log_raw "[WARN]  $*"
    if [ "$BG_MODE" -eq 0 ]; then printf '%s\n' "$_msg"; fi
}

die() {
    _msg="${RED}[ralph]${RESET} $*"
    _log_raw "[DIE]   $*"
    printf '%s\n' "$_msg" >&2
    exit 1
}

# Run a copilot command, tee ALL output to the full log.
# Usage: _copilot [copilot args...]
# In --bg mode stderr is also redirected to the log.
_copilot() {
    if [ "$BG_MODE" -eq 0 ]; then
        copilot "$@" 2>&1 | tee -a "$FULL_LOG"
    else
        copilot "$@" >> "$FULL_LOG" 2>&1
    fi
}

# ── premium request counter ───────────────────────────────────────────────────
PREMIUM_REQUESTS=0

_premium_call() {
    # Wrapper: increment counter then invoke copilot with CODE_MODEL.
    PREMIUM_REQUESTS=$((PREMIUM_REQUESTS + 1))
    log "  [premium call #${PREMIUM_REQUESTS}] invoking ${CODE_MODEL}"
    _copilot "$@"
}

# ── sanity checks ─────────────────────────────────────────────────────────────
# Ensure log dir exists before we try to write the first log entry.
mkdir -p "$LOG_DIR"

# Now that LOG files exist we can use die() / log() properly.
[ -f "$SKILL" ] || die "skill file missing: $SKILL"

if ! command -v copilot >/dev/null 2>&1; then
    die "copilot CLI not found in PATH.
  Install it from: https://github.com/github/gh-copilot
  or via: gh extension install github/gh-copilot
  then log in with: gh auth login"
fi

if ! command -v git >/dev/null 2>&1; then
    die "git not found in PATH"
fi

cd "$REPO_ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
    die "working tree is dirty — commit or stash changes before running ralph"
fi

# ── PID file + signal / sentinel stop mechanism ───────────────────────────────
STOP_REQUESTED=0

printf '%d\n' $$ > "$RALPH_PID_FILE"
trap 'rm -f "$RALPH_PID_FILE"' EXIT
trap 'STOP_REQUESTED=1; warn "Stop signal received — will exit after current task."' INT TERM

# ── initialise log files ──────────────────────────────────────────────────────
# Write headers so the files exist even if ralph exits early.
{
    printf '# Ralph Full Transcript Log\n'
    printf 'Session: %s  |  PID: %d  |  Base branch: %s\n\n' \
        "$SESSION_TS" $$ "$BASE_BRANCH"
} >> "$FULL_LOG"

{
    printf '# Ralph Session Summary\n\n'
    printf '| Key | Value |\n|-----|-------|\n'
    printf '| Session | %s |\n' "$SESSION_TS"
    printf '| PID | %d |\n' $$
    printf '| Base branch | %s |\n' "$BASE_BRANCH"
    if [ "$DURATION_SECS" -gt 0 ]; then
        printf '| Time limit | %dh %dm |\n' \
            $((DURATION_SECS / 3600)) $(((DURATION_SECS % 3600) / 60))
    fi
    if [ "$TASK_LIMIT" -gt 0 ]; then
        printf '| Task limit | %d |\n' "$TASK_LIMIT"
    fi
    if [ -n "$SINGLE_TASK" ]; then
        printf '| Mode | single task: %s |\n' "$SINGLE_TASK"
    else
        printf '| Mode | loop |\n'
    fi
    printf '\n---\n\n'
    printf '## Milestones\n\n'
} >> "$SUMMARY_LOG"

# ── announce startup ──────────────────────────────────────────────────────────
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log "Ralph starting  |  PID $$  |  branch: ${BOLD}${BASE_BRANCH}${RESET}"
log "Full log   : ${FULL_LOG}"
log "Summary log: ${SUMMARY_LOG}"
log "Stop:  touch ${STOP_SENTINEL}"
log "       kill -TERM \$(cat ${RALPH_PID_FILE})"
if [ "$DURATION_SECS" -gt 0 ]; then
    _human="$(( DURATION_SECS / 3600 ))h $(( (DURATION_SECS % 3600) / 60 ))m"
    log "Time limit : ${_human}"
fi
if [ "$TASK_LIMIT" -gt 0 ]; then
    log "Task limit : ${TASK_LIMIT}"
fi
if [ -n "$SINGLE_TASK" ]; then
    log "Mode       : single task — ${BOLD}${SINGLE_TASK}${RESET}"
else
    log "Mode       : loop until no tasks remain"
fi
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

_summary "SESSION START | PID: $$ | branch: $BASE_BRANCH | ts: $SESSION_TS"

# ── helpers ───────────────────────────────────────────────────────────────────

# Ensure docs/plan.md exists; if not, generate it from README + STATUS + AGENTS.
ensure_plan() {
    if [ -f "$PLAN" ]; then
        return 0
    fi
    log "docs/plan.md not found — generating from README.md, STATUS.md, AGENTS.md …"
    README="$(cat "$REPO_ROOT/README.md" 2>/dev/null || true)"
    STATUS="$(cat "$REPO_ROOT/STATUS.md" 2>/dev/null || true)"
    AGENTS="$(cat "$REPO_ROOT/AGENTS.md" 2>/dev/null || true)"

    GENERATED_PLAN="$(copilot \
        -p "You are a senior Godot 4.6 engineer. Based on the three documents below,
produce a prioritised task list for the Careless Whisper project.

Rules:
- Output ONLY the task list, no prose before or after.
- Format each task as exactly:  - [ ] \`task-N\`: Short description (≤10 words)
- Tasks must be small, self-contained, and ordered by dependency (tasks that
  others depend on come first).
- Number tasks starting at 1. Aim for 15 tasks.
- Do NOT include tasks already marked done in STATUS.md.

README.md:
${README}

STATUS.md:
${STATUS}

AGENTS.md:
${AGENTS}" \
        --model "$CHEAP_MODEL" \
        --allow-all-tools --no-ask-user -s \
        --add-dir "$REPO_ROOT" 2>&1)"

    mkdir -p "$(dirname "$PLAN")"
    {
        printf '# Careless Whisper — Task Plan\n\n'
        printf '_Generated by Ralph on %s_\n\n' "$(date '+%Y-%m-%d %H:%M')"
        printf '%s\n' "$GENERATED_PLAN"
    } > "$PLAN"

    log "docs/plan.md created."
    _summary "PLAN READY | docs/plan.md generated by $CHEAP_MODEL"
}

# Return the next open task id (e.g. "task-3"), or empty string if none.
next_task() {
    grep -m1 '^- \[ \] `task-[0-9]\+`' "$PLAN" \
        | sed 's/.*`\(task-[0-9]*\)`.*/\1/' 2>/dev/null || true
}

# Extract the single task line for a given task id.
task_line() {
    _tid="$1"
    grep -m1 "^\- \[.\] \`${_tid}\`" "$PLAN" || true
}

# Mark a task as done in plan.md  (replace "[ ]" with "[x]" for that task line).
mark_task_done() {
    _tid="$1"
    # Use a temp file for portability (no sed -i on all POSIX sh).
    _tmp="${PLAN}.tmp"
    sed "s/^- \[ \] \`${_tid}\`/- [x] \`${_tid}\`/" "$PLAN" > "$_tmp" && mv "$_tmp" "$PLAN"
}

# Print human-readable time remaining string.
time_remaining() {
    _now="$(date +%s)"
    _left=$(( DEADLINE - _now ))
    if [ "$_left" -le 0 ]; then
        printf '0s'
    else
        printf '%dh %dm %ds' $(( _left / 3600 )) $(( (_left % 3600) / 60 )) $(( _left % 60 ))
    fi
}

# Returns 0 (true) when the time deadline has been reached.
deadline_reached() {
    [ "$DEADLINE" -gt 0 ] && [ "$(date +%s)" -ge "$DEADLINE" ]
}

# Returns 0 (true) when a graceful stop has been requested.
stop_requested() {
    [ "$STOP_REQUESTED" -eq 1 ] && return 0
    if [ -f "$STOP_SENTINEL" ]; then
        warn "Stop sentinel found: $STOP_SENTINEL — consuming it."
        rm -f "$STOP_SENTINEL"
        STOP_REQUESTED=1
        return 0
    fi
    return 1
}

# Run GDScript lint; return non-zero on failure.
run_lint() {
    "$REPO_ROOT/scripts/lint.sh" --strict >> "$FULL_LOG" 2>&1
}

# Append a timestamped entry to the persistent ralph log (docs/ralph-log.md).
ralph_log() {
    _entry="$1"
    _logfile="$REPO_ROOT/docs/ralph-log.md"
    mkdir -p "$(dirname "$_logfile")"
    printf '\n## %s\n\n%s\n' "$(date '+%Y-%m-%d %H:%M')" "$_entry" >> "$_logfile"
}

# ── per-task runner ───────────────────────────────────────────────────────────
run_task() {
    TASK_ID="$1"
    BRANCH="task-${TASK_ID#task-}"   # normalise: "task-3" → "task-3", "3" → "task-3"
    # If user passed "task-3" the prefix is already there; if they passed "3" we add it.
    case "$TASK_ID" in
        task-*) BRANCH="$TASK_ID" ;;
        *)      BRANCH="task-${TASK_ID}" ;;
    esac
    TASK_KEY="${BRANCH}"   # canonical id used in plan.md  e.g. "task-3"

    TASK_START_TIME="$(date +%s)"

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "Starting ${BOLD}${TASK_KEY}${RESET}  |  branch: ${BRANCH}"
    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    _summary "TASK START | $TASK_KEY | $(date '+%Y-%m-%d %H:%M')"

    # Ensure we start from a clean slate on the trunk branch.
    git checkout "$BASE_BRANCH" >/dev/null 2>&1
    git pull --ff-only origin "$BASE_BRANCH" >/dev/null 2>&1 \
        || warn "could not fast-forward from origin/${BASE_BRANCH} — continuing on local"
    if git rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        warn "branch ${BRANCH} already exists — checking it out"
        git checkout "$BRANCH" >/dev/null 2>&1
    else
        git checkout -b "$BRANCH" >/dev/null 2>&1
    fi

    TASK_LINE="$(task_line "$TASK_KEY")"
    SKILL_TEXT="$(cat "$SKILL")"

    # ── Step 1: gpt-5-mini produces a written plan ────────────────────────────
    log "Step 1/4 — planning with ${CHEAP_MODEL}"

    IMPL_PLAN="$(copilot \
        -p "You are a senior Godot 4.6 engineer planning a task for Careless Whisper.
Read the skill file and the task line carefully, then write a numbered plan.
Do NOT write any code. Output plain text only.

PROJECT ROOT: ${REPO_ROOT}
TASK: ${TASK_LINE}

SKILL FILE:
${SKILL_TEXT}

Produce:
1. A numbered list of files to create or edit (path + one-sentence purpose).
2. Any scene nodes to add/modify (node type, parent, purpose).
3. Signals to wire (emitter → receiver).
4. Tests or demo scenes to create.
5. Any blockers or concerns before coding starts." \
        --model "$CHEAP_MODEL" \
        --allow-all-tools --no-ask-user -s \
        --add-dir "$REPO_ROOT" 2>&1)"

    _log_raw "=== PLAN for ${TASK_KEY} ===
${IMPL_PLAN}
=== END PLAN ==="

    log "Plan ready."
    _summary "PLAN READY | $TASK_KEY"

    # ── Step 2: claude-sonnet-4.6 implements ─────────────────────────────────
    log "Step 2/4 — implementing with ${CODE_MODEL}"

    _premium_call \
        -p "You are Ralph, the autonomous task agent for the Careless Whisper project.
Implement ${TASK_KEY} in full, following EVERY rule in the skill file below.
Do NOT commit yet. Write all files, run the lint check, fix any failures.
When all files are written and lint is clean print exactly: IMPLEMENTATION_DONE

PROJECT ROOT: ${REPO_ROOT}
TASK: ${TASK_LINE}

PLAN:
${IMPL_PLAN}

SKILL FILE:
${SKILL_TEXT}" \
        --model "$CODE_MODEL" \
        --allow-all \
        --no-ask-user \
        --add-dir "$REPO_ROOT"

    log "Implementation step finished."
    _summary "IMPL DONE | $TASK_KEY | premium_requests so far: $PREMIUM_REQUESTS"

    # ── Step 3: gpt-5-mini self-reviews the diff ──────────────────────────────
    log "Step 3/4 — self-review with ${CHEAP_MODEL}"

    DIFF="$(git diff HEAD 2>&1 | head -800 || true)"

    copilot \
        -p "You are reviewing a Godot 4.6 GDScript implementation for Careless Whisper.
Work through EVERY item in the self-review checklist from the skill file below.
For each item write PASS or FAIL and a one-line reason.
For any FAIL: open the file and fix it now before printing REVIEW_DONE.
Do not skip any checklist item.

TASK: ${TASK_LINE}

GIT DIFF (up to 800 lines):
${DIFF}

SKILL FILE (contains the checklist):
${SKILL_TEXT}

After fixing all failures print exactly: REVIEW_DONE" \
        --model "$CHEAP_MODEL" \
        --allow-all \
        --no-ask-user \
        --add-dir "$REPO_ROOT" \
        >> "$FULL_LOG" 2>&1

    if [ "$BG_MODE" -eq 0 ]; then
        tail -5 "$FULL_LOG"
    fi
    log "Review step finished."
    _summary "REVIEW DONE | $TASK_KEY"

    # ── Step 4: lint with up to 3 fix attempts ────────────────────────────────
    log "Step 4/4 — running lint"

    CHECK_ATTEMPTS=0
    MAX_ATTEMPTS=3
    LINT_PASSED=0

    while [ "$CHECK_ATTEMPTS" -lt "$MAX_ATTEMPTS" ]; do
        CHECK_ATTEMPTS=$((CHECK_ATTEMPTS + 1))
        log "Lint attempt ${CHECK_ATTEMPTS}/${MAX_ATTEMPTS}"

        if run_lint; then
            LINT_PASSED=1
            good "Lint passed."
            _summary "CHECKS PASS | $TASK_KEY | attempt $CHECK_ATTEMPTS/$MAX_ATTEMPTS"
            break
        fi

        warn "Lint failed on attempt ${CHECK_ATTEMPTS}."
        _summary "CHECKS FAIL | $TASK_KEY | attempt $CHECK_ATTEMPTS/$MAX_ATTEMPTS"

        if [ "$CHECK_ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
            ralph_log "BLOCKED on ${TASK_KEY}: lint still failing after ${MAX_ATTEMPTS} attempts. Branch: ${BRANCH}."
            git checkout "$BASE_BRANCH" >/dev/null 2>&1
            git branch -D "$BRANCH" >/dev/null 2>&1 || true
            _summary "TASK BLOCKED | $TASK_KEY | lint gave up after $MAX_ATTEMPTS attempts"
            die "${TASK_KEY} blocked — lint failing after ${MAX_ATTEMPTS} attempts. See docs/ralph-log.md."
        fi

        LINT_ERR="$(cat "$FULL_LOG" | tail -40 || true)"

        log "Asking ${CODE_MODEL} to fix lint failures (attempt ${CHECK_ATTEMPTS})…"
        _premium_call \
            -p "Lint is failing for ${TASK_KEY} in the Careless Whisper Godot project.
Fix every failure shown below. Change ONLY what is needed to pass.
Run ./scripts/lint.sh --strict yourself to verify, then print exactly: FIXES_DONE

LINT OUTPUT (last 40 lines of log):
${LINT_ERR}

SKILL FILE:
${SKILL_TEXT}" \
            --model "$CODE_MODEL" \
            --allow-all \
            --no-ask-user \
            --add-dir "$REPO_ROOT"
    done

    if [ "$LINT_PASSED" -eq 0 ]; then
        # Should have been caught above, but guard defensively.
        die "${TASK_KEY}: lint never passed."
    fi

    # ── Commit and push ───────────────────────────────────────────────────────
    log "Generating commit message with ${CHEAP_MODEL}"

    COMMIT_MSG="$(copilot \
        -p "Write a git commit message for ${TASK_KEY} in the Careless Whisper project.
Format: first line must be exactly 'feat(${TASK_KEY}): <description ≤10 words>'.
Then a blank line. Then one paragraph body: what was done and why.
Output ONLY the commit message text — no markdown fences, no preamble.
Task line: ${TASK_LINE}" \
        --model "$CHEAP_MODEL" \
        --allow-all-tools --no-ask-user -s \
        --add-dir "$REPO_ROOT" 2>&1)"

    log "Committing ${TASK_KEY}"
    git add -A
    git commit -m "$COMMIT_MSG"
    git push origin HEAD

    COMMIT_HASH="$(git rev-parse --short HEAD)"
    good "Task ${TASK_KEY} committed (${COMMIT_HASH}) and pushed on branch ${BRANCH}."

    # Mark done in plan.md and commit that change too.
    mark_task_done "$TASK_KEY"
    git add "$PLAN"
    git commit -m "chore(${TASK_KEY}): mark task done in docs/plan.md" \
        --allow-empty >/dev/null 2>&1 || true
    git push origin HEAD >/dev/null 2>&1 || true

    TASK_END_TIME="$(date +%s)"
    TASK_ELAPSED=$(( TASK_END_TIME - TASK_START_TIME ))

    _summary "COMMIT | $TASK_KEY | hash: $COMMIT_HASH | branch: $BRANCH"
    _summary "TASK DONE | $TASK_KEY | elapsed: ${TASK_ELAPSED}s | premium_requests so far: $PREMIUM_REQUESTS"

    ralph_log "DONE: ${TASK_KEY} — commit ${COMMIT_HASH} pushed on ${BRANCH}. Premium calls this session: ${PREMIUM_REQUESTS}."
}

# ── main ──────────────────────────────────────────────────────────────────────

ensure_plan

# ── single-task mode ──────────────────────────────────────────────────────────
if [ -n "$SINGLE_TASK" ]; then
    if deadline_reached || stop_requested; then
        warn "Stop/deadline condition met before task could start."
        _summary "SESSION END | no tasks run (stop/deadline before start) | premium_requests: $PREMIUM_REQUESTS"
        exit 0
    fi
    run_task "$SINGLE_TASK"
    _summary "SESSION END | 1 task completed | premium_requests: $PREMIUM_REQUESTS | elapsed: $(($(date +%s) - START_TIME))s"
    exit 0
fi

# ── loop mode ─────────────────────────────────────────────────────────────────
TASKS_DONE=0

while true; do
    # Check stop conditions before picking up the next task.
    if deadline_reached; then
        good "Time limit reached. Tasks completed this session: ${TASKS_DONE}."
        _summary "SESSION END | time limit reached | tasks done: $TASKS_DONE | premium_requests: $PREMIUM_REQUESTS | elapsed: $(($(date +%s) - START_TIME))s"
        ralph_log "Session ended: time limit. Tasks completed: ${TASKS_DONE}. Premium requests: ${PREMIUM_REQUESTS}."
        exit 0
    fi

    if stop_requested; then
        good "Graceful stop. Tasks completed this session: ${TASKS_DONE}."
        _summary "SESSION END | graceful stop | tasks done: $TASKS_DONE | premium_requests: $PREMIUM_REQUESTS | elapsed: $(($(date +%s) - START_TIME))s"
        ralph_log "Session ended: graceful stop. Tasks completed: ${TASKS_DONE}. Premium requests: ${PREMIUM_REQUESTS}."
        exit 0
    fi

    if [ "$TASK_LIMIT" -gt 0 ] && [ "$TASKS_DONE" -ge "$TASK_LIMIT" ]; then
        good "Task limit (${TASK_LIMIT}) reached. Tasks completed this session: ${TASKS_DONE}."
        _summary "SESSION END | task limit reached | tasks done: $TASKS_DONE | premium_requests: $PREMIUM_REQUESTS | elapsed: $(($(date +%s) - START_TIME))s"
        ralph_log "Session ended: task limit ${TASK_LIMIT}. Tasks completed: ${TASKS_DONE}. Premium requests: ${PREMIUM_REQUESTS}."
        exit 0
    fi

    TASK_ID="$(next_task)"

    if [ -z "$TASK_ID" ]; then
        good "No more open tasks. Tasks completed this session: ${TASKS_DONE}."
        _summary "SESSION END | no more tasks | tasks done: $TASKS_DONE | premium_requests: $PREMIUM_REQUESTS | elapsed: $(($(date +%s) - START_TIME))s"
        ralph_log "Session ended: all tasks complete. Tasks: ${TASKS_DONE}. Premium requests: ${PREMIUM_REQUESTS}."
        exit 0
    fi

    run_task "$TASK_ID" || {
        _ec=$?
        warn "Task ${TASK_ID} failed (exit ${_ec}) — logging and moving on."
        ralph_log "FAILED: ${TASK_ID} — exit ${_ec}. See full log: ${FULL_LOG}"
        git checkout "$BASE_BRANCH" >/dev/null 2>&1 || true
        git branch -D "task-${TASK_ID#task-}" >/dev/null 2>&1 || true
    }

    TASKS_DONE=$((TASKS_DONE + 1))

    if [ "$DEADLINE" -gt 0 ]; then
        log "Time remaining: $(time_remaining)"
    fi

    sleep 2
done
