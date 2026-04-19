# Changelog

All notable changes to OldIntelClaw are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

See `docs/planning/ROADMAP.md` and GitHub issues labeled `roadmap` for planned post-0.1.0 work.

## [0.1.0] — 2026-04-19

Initial release. Zero-config automated environment setup for running the ZeroClaw
agent framework on 11th Gen Intel hardware (i7-1185G7, 16GB RAM, Iris Xe iGPU) with
OpenVINO and ITREX on Fedora 42.

### Added

**System audit (Epic 1)**
- CPU generation detection for 11th Gen+ Intel processors (#1)
- Fedora version validation (accepts 42+, warns on 41) (#2)
- RAM and Iris Xe iGPU availability checks (#3)
- Existing installation detection for idempotent re-runs (#5)
- Kernel parameter audit for i915 `enable_guc` and `enable_fbc` (#6)
- Optional kernel parameter optimization via `/etc/modprobe.d/i915.conf` (#7)

**Dependency orchestration (Epic 2)**
- Intel system package installation (`intel-compute-runtime`, `level-zero`, etc.) (#9)
- OpenVINO toolkit installation with GPU plugin verification (#10)
- iGPU access via `video` and `render` group membership (#11)
- Rust toolchain installation via `rustup` (#12)
- Python 3.12+ virtualenv with Intel Extension for Transformers (#13)
- Comprehensive dependency verification suite with summary report (#14)

**ZeroClaw setup (Epic 3)**
- ZeroClaw build and installation via `cargo install zeroclaw` (#15)
- Default `config.toml` generation with 5 model endpoints (#16)
- OpenClaw migration detection across common install paths (#17)
- Best-effort OpenClaw `SKILL.md` migration to ZeroClaw format (#18)
- ZeroClaw health check (binary, config, memory < 5MB, cold start < 10ms) (#19)

**Model management (Epic 4)**
- Model store directory structure at `~/.oldintelclaw/models/` with manifest (#20)
- Model download engine with progress, resume, and SHA256 verification (#21)
- Phi-4-mini INT4 conversion for OpenVINO iGPU (3.0 GB) (#22)
- DeepSeek-R1-Distill-Qwen-7B INT4 quantization for ITREX CPU (5.2 GB) (#23)
- Gemma 3 4B INT4 conversion for OpenVINO iGPU (3.2 GB) (#24)
- Qwen3-8B-Thinking INT4 quantization for ITREX CPU (5.5 GB) (#25)
- SmolLM3-3B GGUF download for ZeroClaw native (2.2 GB) (#26)

**Inference server integration (Epic 5)**
- OpenVINO Model Server (OVMS) launch on port 8000 (#27)
- llama-server with OpenVINO backend on port 8001 (#28)
- ITREX inference endpoint on port 8002 (#29)
- ZeroClaw gateway pairing with all three backends (#30)
- Performance validation against PRD targets (TTFT, TPS, cold start, swap) (#31)

**CLI, error handling, and polish (Epic 6)**
- Main entry point at `scripts/setup.sh` with argument parsing (#32)
- CLI flags: `--help`, `--dry-run`, `--skip-models`, `--skip-kernel`, `--verbose`, `--verify-only`, `--reset`
- Structured error handling with JSON state file for resume-from-failure (#33)
- Logging to `~/.oldintelclaw/setup.log` with rotation and verbose mode (#34)
- Progress reporting with step headers (`[Step N/8] ...`) and spinners (#35)
- End-to-end integration tests via BATS (#36)
- User-facing documentation: README quick start and project context (#37)

### Development Process

- **Test coverage:** 238 passing BATS tests (232 unit + 6 end-to-end)
- **TDD discipline:** Every story written as Red → Green → Refactor, confirmed via
  paired `WIP: red tests for Story X.Y` and `green: Story X.Y ...` commits
- **Git hooks:** Pre-commit file placement enforcement and commit-msg attribution
  blocking installed from `.ainative/hooks/`
- **Shared scaffolding:** `scripts/lib/common.sh` for status printing, `scripts/lib/state.sh`
  for JSON state management, `scripts/lib/logging.sh`, `scripts/lib/progress.sh`,
  `tests/test_helper.bash` for BATS test setup

### Known Limitations

- **Fedora 42 only.** Install scripts use `dnf` and Fedora-specific paths. Cross-distro
  support is tracked in #39 (Phase 2 roadmap).
- **11th Gen Intel only.** Hardware audit rejects older CPUs. Broader support is tracked
  in #40 (Phase 2 roadmap).
- **Not validated against real hardware yet.** All 238 tests pass via mocked commands
  and fixture files. First-run validation against an actual i7-1185G7 on Fedora 42 is
  a post-release task — report issues via GitHub.
- **No package distribution yet.** Install via `git clone` + `bash scripts/setup.sh`.
  COPR, Flatpak, and Ansible packaging are tracked in Phase 6 roadmap (#51-#53).

### Backlog and Roadmap

- **v0.1.0 backlog:** `docs/planning/BACKLOG.md` (6 epics, 35 stories, 58 story points)
- **PRD:** `docs/PRD.md` (15 sections including problem statement, user personas,
  success metrics, risks, deployment strategy)
- **Future roadmap:** `docs/planning/ROADMAP.md` and GitHub issues #39-#56
  (Phases 2-7: multi-distro, model management CLI, service management, TUI,
  packaging, advanced features)

[Unreleased]: https://github.com/quaid/OldIntelClaw/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/quaid/OldIntelClaw/releases/tag/v0.1.0
