# OldIntelClaw — Claude Code Project Context

## Project
Zero-config automated environment setup for running the ZeroClaw agent framework on 11th Gen Intel hardware (i7-1185G7, 16GB RAM, Iris Xe iGPU) with OpenVINO and ITREX on Fedora 42.

## Tech Stack
- **Shell scripts** (bash) — audit, install, and config orchestration
- **Python 3.12+** — model management, ITREX quantization, inference servers
- **Rust** — ZeroClaw agent framework (upstream dependency, not built here)
- **BATS** — test framework (`bats tests/unit/` to run all tests)

## Development Process

### Skills (loaded from .ainative/skills/)
Use these skills for all development work:
- **story-workflow** — Fibonacci estimation (0/1/2/3/5/8), story types, backlog
- **mandatory-tdd** — Red/Green/Refactor cycle, 80% coverage minimum
- **git-workflow** — Branch naming, commit messages, PR format, attribution rules
- **file-placement** — Docs in `docs/`, scripts in `scripts/`, nothing loose in root
- **code-quality** — Naming, formatting, security, accessibility
- **delivery-checklist** — Plan → Implement → Test → PR → Verify → Deliver

### Workflow
1. GitHub issues exist for every story (reference `docs/planning/BACKLOG.md` for details)
2. Create feature branch: `feature/{issue-number}-{slug}`
3. TDD: write failing tests first, then minimal implementation
4. Commits reference issues: `Refs #N`
5. PR with `Closes #N`, include test output as proof
6. Merge, verify tests green on main

### Git Hooks (installed from .ainative/hooks/)
- **pre-commit** — blocks .md files in root (except README.md, CLAUDE.md), blocks .sh in root
- **commit-msg** — blocks third-party AI attribution (Claude, ChatGPT, Copilot, etc.)

### Attribution Rules (ZERO TOLERANCE)
- NEVER: "Claude", "Anthropic", "Co-Authored-By: Claude", "Generated with"
- USE: "Built by AINative Dev Team", "Built Using AINative Studio", "Built by Agent Swarm"

## Project Layout
```
OldIntelClaw/
├── CLAUDE.md                       # This file
├── README.md                       # Project README
├── LICENSE                         # Apache 2.0
├── docs/
│   ├── PRD.md                      # Product requirements
│   └── planning/
│       └── BACKLOG.md              # Product backlog (6 epics, 35 stories)
├── scripts/
│   ├── lib/common.sh               # Shared library (status codes, print_status)
│   └── audit/                      # System audit scripts
│       ├── cpu.sh                  # Story 1.1: CPU generation detection
│       ├── os.sh                   # Story 1.2: Fedora version validation
│       ├── hardware.sh             # Story 1.3: RAM and iGPU check
│       ├── installed.sh            # Story 1.4: Existing installation detection
│       ├── kernel.sh               # Story 1.5: Kernel parameter audit
│       └── kernel_optimize.sh      # Story 1.6: Kernel parameter optimization
├── tests/
│   ├── test_helper.bash            # Shared BATS test helper
│   ├── fixtures/                   # Test fixture files (cpuinfo, meminfo, etc.)
│   └── unit/                       # BATS unit tests
├── .ainative/                      # AINative Studio config (primary)
│   ├── AINATIVE.md                 # Project context
│   ├── settings.local.json         # Project settings
│   ├── commands/ → core            # Shared slash commands
│   ├── rules/ → core              # Shared coding rules
│   ├── hooks/ → core              # Git hooks (pre-commit, commit-msg)
│   └── skills/ → core             # Dev process skills
└── .claude/                        # Claude Code config (secondary)
    ├── CLAUDE.md                   # (not here — CLAUDE.md is in project root)
    ├── settings.local.json         # Permissions
    ├── commands/ → core            # Shared commands
    ├── hooks/ → core               # Shared hooks
    └── skills/ → core              # Shared skills
```

## Testing
```bash
# Run all tests
bats tests/unit/

# Run specific test file
bats tests/unit/test_cpu_audit.bats

# All audit scripts use env var overrides for testability:
# OLDINTELCLAW_CPUINFO, OLDINTELCLAW_OS_RELEASE, OLDINTELCLAW_MEMINFO,
# OLDINTELCLAW_LSPCI_OUTPUT, OLDINTELCLAW_DRI_RENDER,
# OLDINTELCLAW_SYSFS_GUC, OLDINTELCLAW_SYSFS_FBC, etc.
```

## Current Status
- **Epic 1: System Audit & Prerequisites** — COMPLETE (6/6 stories, 49 tests)
- **Epic 2: Dependency Orchestration** — Not started
- **Epics 3-6** — Not started
