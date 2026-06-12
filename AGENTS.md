# AGENTS.md

## What This Repo Is

This is an **enforcement kit**, not an application. It installs coding gates and agent rules into other OpenCode projects via `bash setup.sh`. There is no application code to build, test, or run here.

## Critical Rule: Never Edit Files Directly

All file modifications in this repo (and in any project where this kit is installed) must go through the `coding-executor` subagent. Direct `edit`/`write` calls will be blocked by plugins — if you see a confirmation popup, you are violating the rule. Stop immediately and delegate to `coding-executor`.

This applies to *everything*: config changes, doc edits, code fixes, even "trivial" one-line changes. Zero exceptions.

## Key Commands

| Command | Purpose |
|---------|---------|
| `bash setup.sh` | Install/update kit into current directory (self-heal) |
| `bash setup.sh /path/to/target` | Install kit into another project |
| `bash scripts/gate.sh status` | View stage completion status |
| `bash scripts/gate.sh check <stage>` | Check if a stage can be entered |
| `bash scripts/gate.sh pass <stage>` | Mark stage as completed |
| `bash scripts/gate.sh unpass <stage> [reason]` | Revoke stage pass |
| `bash scripts/gate.sh pre <module> <doc>` | Pre-coding verification |
| `bash scripts/gate.sh post <module> '<report>'` | Post-coding verification |
| `bash scripts/gate.sh diagnose` | Diagnose gate status |

Stages: `prd`, `arch`, `detailed`, `code`, `review`

## Architecture

- **`scripts/gate.sh`** — Unified CLI entry point (delegates to `doc-gate.sh` and `verify-coding.sh`)
- **`.opencode/plugin/stage-gate.js`** — Blocks code editing until `doc/.gate/detailed.pass` exists
- **`.opencode/plugin/verify-gate.js`** — Blocks editing until `.verify/` has a pre-check record
- **`.opencode/agent/coding-executor.md`** — The only agent authorized to modify files; enforces a 3-stage flow (load context → read docs & code → verify & save memory)
- **`.opencode/agent/verify-agent.md`** — Independent verification subagent; reads docs & code in a separate session and outputs an objective 5-dimension alignment report
- **`opencode.json`** — Configures permissions: `edit: ask`, bash scripts auto-allowed
- **`.opencode/rules/`** — 3 coding discipline rules (`coding-rules.md` — iron law & 3-stage flow; `endpoint-lock.md` — endpoint alignment; `precise-location.md` — surgical file location before scanning)
- **`.opencode/skills/`** — 5 development skills (prd-writer, system-architect, task-decomposer, code-reviewer, review-expert) with templates and checklists

## Three-Stage Coding Flow (coding-executor)

1. **Pre-check**: `memory_init_session()` + `bash scripts/gate.sh pre <module> <doc>`
2. **Code + Doc sync**: Read design docs in `doc/detailed/`, implement exactly per spec, then sync doc for any user-requested additions
3. **Post-check**: 5-dimension alignment check + `bash scripts/gate.sh post <module> '<report>'` + save memory

## Development Stages

PRD → Architecture → Detailed Design → Coding → Code Review

Each stage requires `review-expert` to pass before the next stage is unblocked. `gate.sh pass/unpass` manages the transitions.

## Design Docs

Detailed design documents live in `doc/detailed/`. The coding-executor reads these before writing any code. If no design doc exists for a module, coding is blocked — ask the user to create one first.
