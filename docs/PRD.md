# PRD: "OldIntelClaw" Local Agent Environment Orchestrator

**Project:** OldIntelClaw
**Version:** 0.1.0
**Date:** 2026-04-02
**Status:** In Development
**Author:** Quaid (quaid on GitHub)

---

## 1. Executive Summary

The "OldIntelClaw" project aims to provide a zero-config, automated environment setup for running the ultra-lightweight **ZeroClaw** agent framework on 11th Gen Intel hardware. This solution leverages the **OpenVINO** toolkit and **Intel Extension for Transformers (ITREX)** to maximize the inference performance of 1B–8B parameter models on mobile processors with limited RAM (16GB), utilizing the Iris Xe iGPU for acceleration.

---

## 2. Problem Statement

Local AI inference on commodity Intel hardware is genuinely difficult to set up. A user with a 2021-era Intel laptop faces a maze of driver versions, quantization formats, kernel parameters, and framework configurations that have no clear path through them. The upstream documentation is fragmented across OpenVINO, ITREX, compute runtime, and ZeroClaw projects, each assuming knowledge of the others.

The result is that most developers with this class of hardware either give up on local inference or resort to cloud-based solutions that compromise privacy. A developer on a 16GB i7-1185G7 laptop who wants a local coding assistant should not need deep expertise in Intel GPU programming to get one running.

OldIntelClaw eliminates this setup problem. It audits the hardware, installs and configures the full Intel AI stack, pulls appropriately quantized models, and delivers a working local inference environment through a single command. The user should be able to run `./setup.sh` and walk away. When they return, the environment is ready.

---

## 3. User Personas

### 3.1 Primary: The Privacy-Conscious Developer

A software developer using a 2021-era Intel laptop as their primary work machine. They want a local coding assistant to improve productivity without sending proprietary code to external APIs. They are comfortable with the Linux command line and can follow technical instructions, but they do not have time to debug GPU driver stack issues. Their tolerance for setup friction is low. They want the tool to work or tell them clearly why it cannot.

### 3.2 Secondary: The Hardware Enthusiast

A technically sophisticated user who wants to extract maximum performance from existing hardware. They understand general system concepts and are willing to tune kernel parameters, but Intel's iGPU toolchain is not their area of expertise. They will read logs, file issues, and contribute fixes. They are likely to be an early adopter and a source of real-world validation across hardware variants.

### 3.3 Tertiary: The Fleet Evaluator

An individual at an organization assessing whether local AI inference is viable across an existing fleet of Intel laptops before committing to a procurement or policy decision. They need the setup to be reproducible and well-documented. They are less concerned with peak performance than with consistent behavior across machines, clear failure modes, and an upgrade path.

---

## 4. Target Hardware and OS Profile

- **Processor:** 11th Gen Intel Core i7-1185G7 (Tiger Lake)
- **Memory:** 16 GB RAM (the hardware floor for 2026 local AI use cases)
- **Graphics:** Intel Iris Xe iGPU (96 Execution Units)
- **Operating System:** Fedora 42 Linux (x86_64)

---

## 5. Functional Requirements

### 5.1 Automated Dependency Orchestration

The app must automate the installation of the complete Intel AI stack on Fedora 42:

- **System Packages:** `openvino`, `intel-compute-runtime`, `intel-level-zero-gpu`, `level-zero`, and `intel-media-driver`
- **Hardware Access:** Automatically add the current user to the `video` and `render` groups to enable iGPU passthrough
- **Build Tools:** Install the Rust toolchain for ZeroClaw and Python 3.12+ for the ITREX backend

### 5.2 ZeroClaw Implementation

The orchestrator will deploy **ZeroClaw** (Rust-based) as the primary agent framework because it consumes less than **5MB of idle RAM**, leaving 99% of the 16GB budget for the AI models.

- **Migration Path:** Include a logic block to migrate existing OpenClaw `SKILL.md` or workspace files if detected
- **Local Server Config:** Automatically configure ZeroClaw's `config.toml` to point to local inference endpoints (e.g., `llamacpp` or `custom` providers)

### 5.3 Model Optimization and Management

The app will fetch and prepare models in the **1B–8B parameter range** using **INT4/NF4 weight-only quantization** to prevent OOM crashes.

- **Quantization Engine:** Use ITREX for CPU-bound "Thinking" models and OpenVINO Model Optimizer for iGPU-bound models
- **Model Store:** Maintain an optimized repository of OpenVINO IR and GGUF files in `~/.oldintelclaw/models/`

---

## 6. Best Methods for Model Execution

On a 16GB i7-1185G7 system, the application must choose the execution path based on the model's architecture:

| Method | Best For | Technical Implementation |
| :--- | :--- | :--- |
| **OpenVINO iGPU** | Multimodal and general chat | Offload model weights to Iris Xe iGPU using the OpenVINO runtime. Reduces CPU load and increases generation speed by 3x–10x. |
| **ITREX INT4** | Thinking and reasoning models | Use Intel Extension for Transformers with `nf4` or `int4` weight-only quantization for DeepSeek-R1 style models. Preserves reasoning accuracy while fitting in ~5GB RAM. |
| **OpenVINO GenAI** | GGUF direct execution | Use the `GGUFReaderV2` in OpenVINO GenAI for direct execution of GGUF models without manual conversion, leveraging graph translation logic. |

---

## 7. Optimized Model Portfolio (16GB Tiers)

| Model | Size | Quant | Recommended Backend |
| :--- | :--- | :--- | :--- |
| **Phi-4-mini (3.8B)** | 3.0 GB | INT4 | **OpenVINO iGPU** (highest speed) |
| **DeepSeek-R1-Distill-Qwen-7B** | 5.2 GB | INT4 | **ITREX CPU** (complex reasoning) |
| **Gemma 3 4B** | 3.2 GB | INT4 | **OpenVINO iGPU** (vision tasks) |
| **Qwen3-8B-Thinking** | 5.5 GB | INT4 | **ITREX CPU** (multilingual coding) |
| **SmolLM3-3B** | 2.2 GB | INT4 | **ZeroClaw Native** (fast background agent) |

---

## 8. Execution Workflow (The "Setup" Command)

1. **System Audit:** Check for 11th Gen+ CPU and Fedora 42
2. **Kernel Optimization:** (Optional) Set `i915.enable_guc=3` and `i915.enable_fbc=1` for better power/perf balance
3. **Dependency Pulse:** `dnf install` OpenVINO, Compute Runtime, and Rust
4. **Security Handshake:** `usermod -aG video,render $USER`
5. **ZeroClaw Build:** `cargo install zeroclaw`
6. **Model Pull:** Download Phi-4-mini and DeepSeek-R1-Distill-7B in INT4
7. **Inference Server:** Launch `ovms` (OpenVINO Model Server) or `llama-server` with the OpenVINO backend
8. **Pairing:** Link the local CLI to the ZeroClaw gateway

---

## 9. Technical Requirements

### 9.1 Technology Stack

- **Orchestration:** Bash scripts (`setup.sh` and supporting modules under `scripts/`)
- **Model Management:** Python 3.12+ with ITREX and OpenVINO Python bindings
- **Agent Framework:** ZeroClaw (Rust, sourced from crates.io upstream)
- **Inference Runtimes:** OpenVINO Model Server (OVMS), llama-server with OpenVINO backend

### 9.2 Non-Functional Requirements

**Idempotency.** Running `./setup.sh` more than once must be safe. Every installation step must check current state before acting. Re-running the script on an already-configured system must produce no errors and leave the system unchanged.

**Install Time.** Full setup from a clean Fedora 42 install to a working inference environment must complete within 10 minutes on a standard broadband connection. Model downloads are the primary time variable and must include progress reporting.

**Graceful Failure with Resume.** If setup is interrupted (network loss, user cancellation, power event), re-running the script must detect completed steps and resume from the point of failure rather than starting over or leaving the system in a broken state.

**Offline Operation.** After the initial setup completes, the system must operate fully without internet access. No runtime calls to external APIs, no telemetry, no phone-home behavior.

**Security.** The setup script must request only the permissions it needs. Group membership changes (`video`, `render`) require explicit user acknowledgment. No operations run as root beyond what `sudo dnf` requires.

**Accessibility.** CLI output must be readable without color as a fallback. All status messages must be human-readable without requiring log parsing. Errors must include a plain-English explanation and a suggested next step.

---

## 10. User Stories and Epics

The full backlog is maintained at `docs/planning/BACKLOG.md`. The table below summarizes the epic structure and sprint assignments.

| Epic | Stories | Story Points | Sprint |
|------|---------|--------------|--------|
| Epic 1: System Audit and Prerequisites | 6 | 8 | Sprint 1 |
| Epic 2: Dependency Orchestration | 6 | 10 | Sprint 1 |
| Epic 3: ZeroClaw Setup and Configuration | 5 | 9 | Sprint 2 |
| Epic 4: Model Management and Optimization | 7 | 12 | Sprint 2 |
| Epic 5: Inference Server and Integration | 5 | 10 | Sprint 3 |
| Epic 6: CLI UX, Error Handling, and Documentation | 6 | 9 | Sprint 3 |
| **Total** | **35 stories** | **58 pts** | **3 sprints** |

### Sprint Dependency Chain

```
Sprint 1: [Epic 1: Audit] → [Epic 2: Dependencies]
Sprint 2: [Epic 3: ZeroClaw] + [Epic 4: Models]  (parallel, both depend on Epic 2)
Sprint 3: [Epic 5: Server & Integration] → [Epic 6: Polish]
           (Epic 5 depends on Epics 3 + 4)
```

See `docs/planning/BACKLOG.md` for acceptance criteria, technical details, and testing plans for each story.

---

## 11. Success Metrics

The following outcomes define a successful 0.1.0 release. Each metric is binary (pass/fail) unless otherwise noted.

| Metric | Target | Measurement Method |
| :--- | :--- | :--- |
| Unattended setup completion | `./setup.sh` completes without manual intervention on target hardware | Manual test run on a clean Fedora 42 install |
| Model portfolio availability | All 5 models in the portfolio load and respond to a test prompt | Automated smoke test in `scripts/test/model_smoke.sh` |
| Time to First Token (TTFT) | < 500ms on iGPU for 4B-class models | Benchmark script with timestamped output |
| Tokens per Second (TPS) | > 15 t/s for 4B-class models on iGPU | Benchmark script, 10-run average |
| ZeroClaw cold start | < 10ms for the agent framework itself | Measured via `time zeroclaw --version` as proxy |
| Memory stability | Zero disk-swapping during standard 4k context inference | `vmstat` monitoring during inference benchmark |
| Idempotency | Re-running `./setup.sh` on a configured system exits cleanly with no errors | Automated test: run setup twice, diff system state |
| Intel GPU knowledge required | Zero: user needs no prior knowledge of Intel GPU tooling | Validated by user testing with target personas |

---

## 12. Implementation Timeline

The project is organized into three one-week sprints. Dates assume a start date of 2026-04-07.

### Sprint 1: Audit and Dependencies (Week of 2026-04-07)

**Goal:** Validate the target environment and establish the full Intel AI software stack.

**Epics in scope:**
- Epic 1: System Audit and Prerequisites (8 pts) — CPU detection, memory check, OS version, iGPU detection, disk space, group membership
- Epic 2: Dependency Orchestration (10 pts) — OpenVINO install, compute runtime, Level Zero, Rust toolchain, Python environment

**Sprint exit criteria:** `dnf install` completes cleanly, user is in `video` and `render` groups, `python3.12 -c "import openvino"` succeeds, `rustc --version` returns a valid version.

### Sprint 2: ZeroClaw and Models (Week of 2026-04-14)

**Goal:** Install the ZeroClaw agent framework and populate the model portfolio.

**Epics in scope:**
- Epic 3: ZeroClaw Setup and Configuration (9 pts) — `cargo install zeroclaw`, `config.toml` generation, OpenClaw migration logic, endpoint wiring
- Epic 4: Model Management and Optimization (12 pts) — Hugging Face download, INT4 quantization via ITREX, OpenVINO IR conversion, model smoke tests

**Sprint exit criteria:** `zeroclaw --version` succeeds, all 5 models are present in `~/.oldintelclaw/models/` and pass individual load tests.

### Sprint 3: Servers, Integration, and Polish (Week of 2026-04-21)

**Goal:** Bring up the inference servers, complete end-to-end integration, and harden the user experience.

**Epics in scope:**
- Epic 5: Inference Server and Integration (10 pts) — OVMS or llama-server startup, endpoint health checks, ZeroClaw gateway pairing, benchmark script
- Epic 6: CLI UX, Error Handling, and Documentation (9 pts) — progress output, colorless fallback, error messages with remediation guidance, README and setup guide

**Sprint exit criteria:** All success metrics in Section 11 pass on target hardware. `./setup.sh` completes unattended on a clean system. Re-run is clean.

---

## 13. Dependencies and Risks

### 13.1 External Dependencies

| Dependency | Owner | Nature |
| :--- | :--- | :--- |
| ZeroClaw on crates.io | Upstream project | `cargo install zeroclaw` must resolve. If the crate is unavailable or yanked, the build step fails. |
| Model files on Hugging Face | Model authors / HF platform | Models could be taken down, access-gated, or moved. Downloads will be verified against known checksums. |
| OpenVINO Fedora 42 packages | Intel / RPM Fusion | Package compatibility with Fedora 42 is not guaranteed at project start. Fallback: build from source or use the Intel pip packages. |
| ITREX Python bindings | Intel | Python 3.12 compatibility must be validated. ITREX has historically lagged on new Python versions. |

### 13.2 Risks

**iGPU driver issues on newer kernels.** The `i915` kernel module behavior can change between Fedora kernel updates. A kernel update after setup could break iGPU access. Mitigation: document the tested kernel version, pin kernel updates in setup documentation, include a re-validation script.

**Model quantization quality varies by architecture.** INT4 quantization degrades differently across model families. Reasoning models (DeepSeek-R1 style) are particularly sensitive. Mitigation: validate each model in the portfolio with a quality benchmark before including it. Keep the portfolio small and curated rather than comprehensive.

**Disk space at model download time.** The full model portfolio requires approximately 20GB of disk space during download (pre-deduplication). Users with smaller drives may hit failures mid-download. Mitigation: check available disk space in Epic 1 audit and warn before downloading.

**`cargo install` build times.** On a constrained machine, building ZeroClaw from source may take longer than expected and could time out in automated contexts. Mitigation: set explicit timeout values and provide a pre-built binary fallback path if one becomes available upstream.

**Solo developer bandwidth.** The project is staffed by one developer with AI agent support. Scope creep in any sprint directly delays subsequent sprints. Mitigation: strict story point discipline, no new stories added to a sprint in progress without removing equivalent points.

---

## 14. Deployment Strategy

### 14.1 Initial Release (0.1.0)

Distribution is via Git clone. The user clones the repository and runs the setup script:

```bash
git clone https://github.com/quaid/OldIntelClaw.git
cd OldIntelClaw
./setup.sh
```

There is no package manager distribution for 0.1.0. This keeps the initial release simple and allows rapid iteration based on early feedback.

### 14.2 Future Distribution

The following distribution paths are under consideration for post-0.1.0 releases, in order of priority:

- **Fedora COPR:** A COPR repository would allow `dnf install oldintelclaw` on Fedora systems. This is the most natural path for the target user base and aligns with Fedora packaging conventions.
- **Flatpak:** A Flatpak bundle would extend reach to other Linux distributions while providing a sandboxed, self-contained install. This is more complex to maintain but increases the addressable user base significantly.
- **RPM package:** A direct RPM for submission to RPM Fusion or the Fedora package collection. Requires meeting Fedora packaging guidelines and a review process.

Distribution method selection for 0.2.0 will be driven by user feedback on the 0.1.0 Git-clone experience and by which hardware variants prove to work reliably enough to warrant broader distribution.

### 14.3 Update Path

For 0.1.0, users update by pulling the latest commit and re-running `./setup.sh`. Because setup is idempotent, re-running applies any new configuration or package changes without resetting a working environment.

---

## 15. Performance Targets

- **Time-to-First-Token (TTFT):** < 500ms on iGPU
- **Tokens per Second (TPS):** > 15 t/s for 4B-class models on iGPU
- **Cold Start:** < 10ms for the ZeroClaw agent framework itself
- **Reliability:** Zero disk-swapping during standard 4k context inference
