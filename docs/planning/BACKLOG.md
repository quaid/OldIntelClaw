# OldIntelClaw: Product Backlog

**Project:** OldIntelClaw — Zero-config automated environment setup for running the ZeroClaw agent framework on 11th Gen Intel hardware with OpenVINO and ITREX
**Duration:** 3 sprints (1 week each)
**Team:** Solo developer + AINative Agent Swarm
**Total Story Points:** 58

---

## Backlog Overview

| Epic | Stories | Story Points | Sprint |
|------|---------|--------------|--------|
| **Epic 1:** System Audit & Prerequisites | 6 | 8 | Sprint 1 |
| **Epic 2:** Dependency Orchestration | 6 | 10 | Sprint 1 |
| **Epic 3:** ZeroClaw Setup & Configuration | 5 | 9 | Sprint 2 |
| **Epic 4:** Model Management & Optimization | 7 | 12 | Sprint 2 |
| **Epic 5:** Inference Server & Integration | 5 | 10 | Sprint 3 |
| **Epic 6:** CLI UX, Error Handling & Documentation | 6 | 9 | Sprint 3 |
| **Total** | **35 stories** | **58 pts** | **3 sprints** |

### Sprint Dependency Chain

```
Sprint 1: [Epic 1: Audit] → [Epic 2: Dependencies]
Sprint 2: [Epic 3: ZeroClaw] + [Epic 4: Models]  (parallel, both depend on Epic 2)
Sprint 3: [Epic 5: Server & Integration] → [Epic 6: Polish]
           (Epic 5 depends on Epics 3 + 4)
```

---

## Story Point Reference

- **0 points:** Trivial (typo, tiny config change)
- **1 point:** Clear, contained (single module, well-defined output)
- **2 points:** Slightly complex, well-defined (multiple files, some unknowns)
- **3+ points:** MUST SPLIT into smaller stories first

---

# Epic 1: System Audit & Prerequisites

**Goal:** Validate that the target machine meets all hardware and OS requirements before any installation begins. Provide clear pass/fail/warning output for each check.
**Sprint:** Sprint 1
**Story Points:** 8

---

## User Story 1.1: CPU Generation Detection

**As a** user running setup on my machine
**I want** the tool to detect whether I have an 11th Gen+ Intel CPU
**So that** I know immediately if my hardware is supported

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Reads `/proc/cpuinfo` and parses CPU model name
- [ ] Identifies Intel generation (11th, 12th, 13th, 14th, etc.)
- [ ] Returns PASS for 11th Gen+, FAIL with clear message for older CPUs
- [ ] Handles edge cases: AMD CPUs, VMs without full CPUID

### Technical Details
- **Files:** `src/audit/cpu.rs` (or `scripts/audit/cpu.sh`)
- **Method:** Parse `model name` field from `/proc/cpuinfo`, match against `11th Gen|12th Gen|13th Gen|14th Gen|Core Ultra`
- **Dependencies:** None

### Testing Plan
- [ ] Unit test with mock `/proc/cpuinfo` content for 11th Gen i7-1185G7
- [ ] Unit test with mock content for unsupported 10th Gen CPU
- [ ] Unit test with mock content for AMD CPU
- [ ] Unit test with 12th/13th/14th Gen content (should pass)

### Definition of Done
- CPU detection returns correct result on target hardware
- All unit tests pass
- Clear error message displayed for unsupported CPUs

---

## User Story 1.2: Fedora Version Validation

**As a** user running setup
**I want** the tool to verify I'm on Fedora 42
**So that** package installation commands are compatible with my OS

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Reads `/etc/os-release` and parses `ID` and `VERSION_ID` fields
- [ ] Returns PASS for Fedora 42+, WARN for Fedora 41 (may work), FAIL for non-Fedora
- [ ] Outputs detected OS name and version in diagnostic output

### Technical Details
- **Files:** `src/audit/os.rs` (or `scripts/audit/os.sh`)
- **Method:** Parse `/etc/os-release` for `ID=fedora` and `VERSION_ID=42`
- **Dependencies:** None

### Testing Plan
- [ ] Unit test with Fedora 42 os-release content
- [ ] Unit test with Fedora 41 os-release content (WARN)
- [ ] Unit test with Ubuntu os-release content (FAIL)

### Definition of Done
- OS detection returns correct result on Fedora 42
- All unit tests pass

---

## User Story 1.3: RAM and iGPU Availability Check

**As a** user running setup
**I want** the tool to verify I have at least 16GB RAM and an Iris Xe iGPU
**So that** I know model loading and iGPU inference will work

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Checks total RAM via `/proc/meminfo` (MemTotal)
- [ ] Returns PASS for >= 15GB (accounting for firmware reservation), WARN for 12-15GB, FAIL for < 12GB
- [ ] Checks for Intel iGPU via `lspci` or `/sys/class/drm/`
- [ ] Identifies Iris Xe specifically (device ID 0x9a49 for TGL)
- [ ] Verifies `/dev/dri/renderD128` device node exists

### Technical Details
- **Files:** `src/audit/hardware.rs` (or `scripts/audit/hardware.sh`)
- **Method:** Parse `/proc/meminfo` for `MemTotal`, parse `lspci -nn` for Intel VGA controller
- **Dependencies:** `pciutils` (lspci) — typically pre-installed on Fedora

### Testing Plan
- [ ] Unit test with 16GB meminfo content
- [ ] Unit test with 8GB meminfo content (FAIL)
- [ ] Integration test verifying `/dev/dri/renderD128` on target hardware

### Definition of Done
- RAM and iGPU detection correct on target i7-1185G7 machine
- All unit tests pass

---

## User Story 1.4: Existing Installation Detection

**As a** user re-running setup
**I want** the tool to detect already-installed components
**So that** it skips redundant installations and runs idempotently

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P1 (High)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Detects existing OpenVINO installation (`python3 -c "import openvino"` or `rpm -q openvino`)
- [ ] Detects existing Rust toolchain (`rustc --version`)
- [ ] Detects existing ZeroClaw binary (`which zeroclaw` or `zeroclaw --version`)
- [ ] Detects existing Python 3.12+ (`python3 --version`)
- [ ] Detects existing ITREX (`python3 -c "import intel_extension_for_transformers"`)
- [ ] Reports each component as INSTALLED (skip) or MISSING (will install)
- [ ] Stores detection results for use by downstream installation steps

### Technical Details
- **Files:** `src/audit/installed.rs` (or `scripts/audit/installed.sh`)
- **Method:** Run version commands, check exit codes, parse version strings
- **Dependencies:** None (checks for the dependencies themselves)

### Testing Plan
- [ ] Unit test with all components missing (clean install scenario)
- [ ] Unit test with partial installation (e.g., Rust present, OpenVINO missing)
- [ ] Unit test with all components present (skip-all scenario)

### Definition of Done
- Detection correctly identifies installed vs missing components
- Downstream steps respect skip flags
- All unit tests pass

---

## User Story 1.5: Kernel Parameter Audit

**As a** user running setup
**I want** the tool to check current Intel GPU kernel parameters
**So that** I know if kernel optimization would improve performance

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P1 (High)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Reads current `i915.enable_guc` value from `/sys/module/i915/parameters/enable_guc`
- [ ] Reads current `i915.enable_fbc` value from `/sys/module/i915/parameters/enable_fbc`
- [ ] Reports current vs recommended values (guc=3, fbc=1)
- [ ] Returns INFO if already optimal, WARN if suboptimal with improvement suggestion

### Technical Details
- **Files:** `src/audit/kernel.rs` (or `scripts/audit/kernel.sh`)
- **Method:** Read sysfs parameter files directly
- **Dependencies:** None

### Testing Plan
- [ ] Unit test with optimal values (guc=3, fbc=1)
- [ ] Unit test with default values (guc=0, fbc=-1)
- [ ] Unit test with missing sysfs files (non-Intel GPU)

### Definition of Done
- Kernel parameter check returns correct status on target hardware
- All unit tests pass

---

## User Story 1.6: Kernel Parameter Optimization

**As a** user who wants maximum iGPU performance
**I want** the tool to optionally configure kernel parameters for Intel GPU
**So that** GuC/HuC firmware submission and framebuffer compression are enabled

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P2 (Medium)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Only runs when explicitly requested (not part of default setup)
- [ ] Creates `/etc/modprobe.d/i915.conf` with `options i915 enable_guc=3 enable_fbc=1`
- [ ] Backs up existing `/etc/modprobe.d/i915.conf` if present
- [ ] Runs `dracut -f` to regenerate initramfs
- [ ] Warns user that a reboot is required for changes to take effect
- [ ] Requires sudo/root — exits cleanly with message if not root

### Technical Details
- **Files:** `src/audit/kernel_optimize.rs` (or `scripts/audit/kernel_optimize.sh`)
- **Method:** Write modprobe config, regenerate initramfs
- **Dependencies:** Root access, dracut

### Testing Plan
- [ ] Unit test verifying correct config file content is generated
- [ ] Unit test verifying backup of existing config
- [ ] Integration test on target hardware (manual — requires reboot)

### Definition of Done
- Config file written correctly
- Existing config backed up
- Reboot warning displayed
- Unit tests pass

---

# Epic 2: Dependency Orchestration

**Goal:** Install the complete Intel AI stack on Fedora 42, including OpenVINO, compute runtime, Rust toolchain, and Python/ITREX. All installations must be idempotent.
**Sprint:** Sprint 1
**Story Points:** 10

---

## User Story 2.1: Install Intel System Packages

**As a** user running setup
**I want** the Intel compute runtime and Level Zero packages installed
**So that** the iGPU is accessible for OpenVINO inference

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Installs `intel-compute-runtime`, `intel-level-zero-gpu`, `level-zero`, `intel-media-driver` via dnf
- [ ] Skips packages already installed (idempotent)
- [ ] Handles DNF lock contention gracefully (retry with backoff)
- [ ] Verifies installation by checking `rpm -q` for each package
- [ ] Requires sudo — exits with clear message if not root

### Technical Details
- **Files:** `src/install/intel_packages.rs` (or `scripts/install/intel_packages.sh`)
- **Command:** `sudo dnf install -y intel-compute-runtime intel-level-zero-gpu level-zero intel-media-driver`
- **Dependencies:** Fedora 42 with RPM Fusion or Intel repos configured

### Testing Plan
- [ ] Integration test on Fedora 42 with packages not installed
- [ ] Integration test on Fedora 42 with packages already installed (idempotency)
- [ ] Unit test for DNF lock retry logic

### Definition of Done
- All four packages installed and queryable via `rpm -q`
- `/dev/dri/renderD128` accessible
- Script is idempotent (safe to re-run)

---

## User Story 2.2: Install OpenVINO Toolkit

**As a** user running setup
**I want** OpenVINO installed and configured
**So that** I can run model inference on the iGPU

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Installs OpenVINO via `pip install openvino` or system package
- [ ] Installs OpenVINO GenAI package (`pip install openvino-genai`)
- [ ] Verifies installation: `python3 -c "import openvino; print(openvino.__version__)"`
- [ ] Verifies GPU plugin available: `python3 -c "from openvino import Core; print(Core().available_devices)"`
- [ ] GPU device appears in available devices list
- [ ] Skips if already installed at correct version

### Technical Details
- **Files:** `src/install/openvino.rs` (or `scripts/install/openvino.sh`)
- **Method:** pip install in a venv at `~/.oldintelclaw/venv/` or system-wide
- **Dependencies:** Python 3.12+, Intel system packages (Story 2.1)

### Testing Plan
- [ ] Integration test: import openvino succeeds
- [ ] Integration test: GPU device detected
- [ ] Unit test for version parsing and skip logic

### Definition of Done
- `import openvino` succeeds
- GPU appears in `Core().available_devices`
- Installation is idempotent

---

## User Story 2.3: Configure iGPU Access

**As a** user running setup
**I want** my user account added to the video and render groups
**So that** I can access the iGPU without running as root

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Adds current user to `video` group via `usermod -aG video $USER`
- [ ] Adds current user to `render` group via `usermod -aG render $USER`
- [ ] Skips if user is already in both groups
- [ ] Warns that logout/login is required for group changes to take effect
- [ ] Verifies group membership with `id` command

### Technical Details
- **Files:** `src/install/gpu_access.rs` (or `scripts/install/gpu_access.sh`)
- **Method:** Check `id -nG $USER` for existing membership, then `sudo usermod -aG`
- **Dependencies:** Root access

### Testing Plan
- [ ] Unit test for group membership detection
- [ ] Integration test on target hardware

### Definition of Done
- User is in video and render groups (verified by `id`)
- Logout warning displayed if groups were newly added

---

## User Story 2.4: Install Rust Toolchain

**As a** user running setup
**I want** the Rust toolchain installed
**So that** ZeroClaw can be built from source

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Installs Rust via `rustup` if not present
- [ ] Verifies `rustc --version` and `cargo --version`
- [ ] Skips if Rust is already installed and at a compatible version
- [ ] Adds `~/.cargo/bin` to PATH if not already present

### Technical Details
- **Files:** `src/install/rust.rs` (or `scripts/install/rust.sh`)
- **Command:** `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y`
- **Dependencies:** curl, internet access

### Testing Plan
- [ ] Integration test: `rustc --version` succeeds after install
- [ ] Unit test for version check and skip logic

### Definition of Done
- `rustc` and `cargo` available in PATH
- Installation is idempotent

---

## User Story 2.5: Install Python 3.12+ and ITREX

**As a** user running setup
**I want** Python 3.12+ and Intel Extension for Transformers installed
**So that** CPU-bound thinking models can run with INT4 quantization

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Verifies Python 3.12+ is available (Fedora 42 ships Python 3.13)
- [ ] Creates project virtualenv at `~/.oldintelclaw/venv/` if not exists
- [ ] Installs `intel-extension-for-transformers` in the virtualenv
- [ ] Installs `transformers`, `torch` (CPU), `optimum-intel` as dependencies
- [ ] Verifies: `python3 -c "import intel_extension_for_transformers"`
- [ ] Skips if already installed at compatible version

### Technical Details
- **Files:** `src/install/python_itrex.rs` (or `scripts/install/python_itrex.sh`)
- **Method:** `python3 -m venv ~/.oldintelclaw/venv/ && pip install intel-extension-for-transformers`
- **Dependencies:** Python 3.12+, internet access

### Testing Plan
- [ ] Integration test: ITREX import succeeds
- [ ] Unit test for version parsing
- [ ] Integration test: quantization function callable

### Definition of Done
- ITREX importable in the project virtualenv
- INT4 quantization functions available

---

## User Story 2.6: Dependency Verification Suite

**As a** user who just completed installation
**I want** a comprehensive verification of all installed dependencies
**So that** I know the installation succeeded before proceeding to ZeroClaw setup

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P1 (High)
**Sprint:** Sprint 1

### Acceptance Criteria
- [ ] Runs all verification checks from Stories 2.1–2.5
- [ ] Produces a summary table: component, version, status (OK/FAIL)
- [ ] Checks `openvino` version and GPU plugin
- [ ] Checks `rustc` and `cargo` versions
- [ ] Checks Python version and ITREX import
- [ ] Checks group membership (video, render)
- [ ] Checks device node `/dev/dri/renderD128`
- [ ] Returns overall PASS/FAIL with list of failing components
- [ ] Saves verification report to `~/.oldintelclaw/verify.log`

### Technical Details
- **Files:** `src/verify/dependencies.rs` (or `scripts/verify/dependencies.sh`)
- **Method:** Run each check, collect results, format table
- **Dependencies:** All Epic 2 stories complete

### Testing Plan
- [ ] Integration test on fully-installed system (all PASS)
- [ ] Unit test with simulated missing component (partial FAIL)

### Definition of Done
- Verification suite runs and produces clear summary
- Report saved to log file
- All checks pass on target hardware after full install

---

# Epic 3: ZeroClaw Setup & Configuration

**Goal:** Build, install, and configure the ZeroClaw agent framework with local inference endpoints. Support migration from OpenClaw if detected.
**Sprint:** Sprint 2
**Story Points:** 9

---

## User Story 3.1: Build and Install ZeroClaw

**As a** user running setup
**I want** ZeroClaw built and installed from source
**So that** I have the ultra-lightweight agent framework running locally

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 2

### Acceptance Criteria
- [ ] Installs ZeroClaw via `cargo install zeroclaw`
- [ ] Verifies binary is in PATH: `zeroclaw --version`
- [ ] Skips if ZeroClaw is already installed at compatible version
- [ ] Creates `~/.oldintelclaw/` directory structure if not exists
- [ ] Build completes within 5 minutes on target hardware

### Technical Details
- **Files:** `src/install/zeroclaw.rs` (or `scripts/install/zeroclaw.sh`)
- **Command:** `cargo install zeroclaw`
- **Binary location:** `~/.cargo/bin/zeroclaw`
- **Dependencies:** Rust toolchain (Epic 2, Story 2.4)

### Testing Plan
- [ ] Integration test: `zeroclaw --version` succeeds
- [ ] Unit test for version check and skip logic
- [ ] Integration test: re-run is idempotent

### Definition of Done
- `zeroclaw --version` returns valid version
- `~/.oldintelclaw/` directory exists
- Installation is idempotent

---

## User Story 3.2: Generate Default config.toml

**As a** user running setup
**I want** ZeroClaw's config.toml auto-generated with local inference endpoints
**So that** ZeroClaw connects to the local inference server out of the box

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 2

### Acceptance Criteria
- [ ] Creates `~/.oldintelclaw/config.toml` with default configuration
- [ ] Configures provider as `llamacpp` pointing to `http://localhost:8000/v1`
- [ ] Sets default model to Phi-4-mini
- [ ] Configures model aliases mapping model names to local endpoints
- [ ] Backs up existing config.toml before overwriting
- [ ] Config is valid TOML and parseable by ZeroClaw

### Technical Details
- **Files:** `src/config/zeroclaw_config.rs` (or `scripts/config/zeroclaw_config.sh`)
- **Output:** `~/.oldintelclaw/config.toml`
- **Config structure:**
  ```toml
  [provider]
  type = "llamacpp"
  base_url = "http://localhost:8000/v1"
  default_model = "phi-4-mini"

  [models.phi-4-mini]
  backend = "openvino-igpu"
  path = "~/.oldintelclaw/models/openvino/phi-4-mini/"

  [models.deepseek-r1-7b]
  backend = "itrex-cpu"
  path = "~/.oldintelclaw/models/itrex/deepseek-r1-distill-qwen-7b/"
  ```
- **Dependencies:** ZeroClaw installed (Story 3.1)

### Testing Plan
- [ ] Unit test: generated TOML is valid and contains required fields
- [ ] Unit test: existing config backup works
- [ ] Integration test: ZeroClaw can parse the generated config

### Definition of Done
- `~/.oldintelclaw/config.toml` exists and is valid
- ZeroClaw starts without config errors
- Existing config backed up if present

---

## User Story 3.3: OpenClaw Migration Detection

**As a** user with an existing OpenClaw installation
**I want** the setup tool to detect my OpenClaw files
**So that** I'm offered the option to migrate my workspace

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P1 (High)
**Sprint:** Sprint 2

### Acceptance Criteria
- [ ] Scans common locations for OpenClaw files: `~/.openclaw/`, `./SKILL.md`, `./openclaw.yaml`
- [ ] Reports whether OpenClaw workspace/config files were found
- [ ] Lists detected files and their locations
- [ ] Does NOT modify anything — detection only

### Technical Details
- **Files:** `src/migrate/detect.rs` (or `scripts/migrate/detect.sh`)
- **Method:** Check filesystem paths for OpenClaw artifacts
- **Dependencies:** None

### Testing Plan
- [ ] Unit test with mock OpenClaw directory structure
- [ ] Unit test with no OpenClaw files present
- [ ] Unit test with partial OpenClaw installation

### Definition of Done
- Correctly detects presence/absence of OpenClaw files
- All unit tests pass

---

## User Story 3.4: OpenClaw SKILL.md Migration

**As a** user migrating from OpenClaw
**I want** my SKILL.md and workspace files converted to ZeroClaw format
**So that** I keep my existing agent configurations

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P1 (High)
**Sprint:** Sprint 2

### Acceptance Criteria
- [ ] Reads OpenClaw `SKILL.md` files and converts to ZeroClaw-compatible format
- [ ] Converts OpenClaw workspace config to ZeroClaw `config.toml` entries
- [ ] Preserves original files (copies, does not move)
- [ ] Migration is best-effort — logs warnings for unconvertible fields, does not fail setup
- [ ] Writes migration report to `~/.oldintelclaw/migration.log`

### Technical Details
- **Files:** `src/migrate/openclaw.rs` (or `scripts/migrate/openclaw.sh`)
- **Method:** Parse SKILL.md markdown, extract agent definitions, map to ZeroClaw config sections
- **Dependencies:** OpenClaw detection (Story 3.3)

### Testing Plan
- [ ] Unit test with sample OpenClaw SKILL.md content
- [ ] Unit test with empty/malformed SKILL.md (graceful failure)
- [ ] Unit test verifying original files are not modified

### Definition of Done
- Converted files are valid ZeroClaw format
- Original OpenClaw files preserved
- Migration report generated
- Setup does not fail even if migration partially fails

---

## User Story 3.5: ZeroClaw Health Check

**As a** user who just installed ZeroClaw
**I want** a health check that verifies ZeroClaw is working
**So that** I know the agent framework is ready before configuring models

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 2

### Acceptance Criteria
- [ ] Verifies ZeroClaw binary runs: `zeroclaw --version`
- [ ] Verifies config.toml is parseable by ZeroClaw
- [ ] Checks ZeroClaw idle memory usage is < 5MB
- [ ] Measures cold start time (target: < 10ms)
- [ ] Reports health status: HEALTHY / DEGRADED / FAILED

### Technical Details
- **Files:** `src/verify/zeroclaw_health.rs` (or `scripts/verify/zeroclaw_health.sh`)
- **Method:** Launch ZeroClaw, measure startup time and RSS, verify config parsing
- **Dependencies:** ZeroClaw installed and configured (Stories 3.1, 3.2)

### Testing Plan
- [ ] Integration test on target hardware with valid config
- [ ] Unit test with invalid config.toml (expect FAILED status)
- [ ] Performance test: cold start < 10ms

### Definition of Done
- Health check returns HEALTHY on properly configured system
- Cold start time reported
- Memory usage reported and under 5MB

---

# Epic 4: Model Management & Optimization

**Goal:** Download, quantize, and prepare the model portfolio for inference. Maintain an organized model store at `~/.oldintelclaw/models/` with support for OpenVINO IR, ITREX INT4, and GGUF formats.
**Sprint:** Sprint 2
**Story Points:** 12

---

## User Story 4.1: Create Model Store Directory Structure

**As a** user running setup
**I want** the model store directory created with proper structure
**So that** models are organized by backend type

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P0 (Critical)
**Sprint:** Sprint 2

### Acceptance Criteria
- [ ] Creates `~/.oldintelclaw/models/` root directory
- [ ] Creates subdirectories: `openvino/`, `itrex/`, `gguf/`
- [ ] Creates `~/.oldintelclaw/models/manifest.json` (empty registry)
- [ ] Skips creation if directories already exist
- [ ] Sets appropriate permissions (700 for model directory)

### Technical Details
- **Files:** `src/models/store.rs` (or `scripts/models/store.sh`)
- **Manifest format:**
  ```json
  {
    "version": 1,
    "models": {}
  }
  ```
- **Dependencies:** `~/.oldintelclaw/` directory exists (Story 3.1)

### Testing Plan
- [ ] Unit test: directories created correctly
- [ ] Unit test: manifest.json is valid JSON
- [ ] Unit test: idempotent (re-run safe)

### Definition of Done
- Directory structure exists with correct permissions
- Empty manifest.json created
- Idempotent

---

## User Story 4.2: Model Download Engine with Progress Reporting

**As a** user downloading large model files
**I want** to see download progress and be able to resume interrupted downloads
**So that** I know the download is working and don't have to restart from scratch

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 2

### Acceptance Criteria
- [ ] Downloads model files from Hugging Face Hub
- [ ] Shows progress bar with percentage, speed, and ETA
- [ ] Supports resuming interrupted downloads (HTTP Range headers)
- [ ] Verifies downloaded files via SHA256 checksum
- [ ] Reports download size before starting (confirm if > 5GB)
- [ ] Stores downloads in appropriate backend subdirectory

### Technical Details
- **Files:** `src/models/download.py` (or `scripts/models/download.sh`)
- **Method:** Python script using `huggingface_hub` library, or `wget`/`curl` with resume support
- **Dependencies:** Python 3.12+, internet access, `huggingface_hub` pip package

### Testing Plan
- [ ] Unit test for checksum verification logic
- [ ] Unit test for resume logic (mock HTTP Range response)
- [ ] Integration test: download a small test file from HF Hub

### Definition of Done
- Downloads complete with progress reporting
- Interrupted downloads resume correctly
- Checksums verified after download

---

## User Story 4.3: Phi-4-mini INT4 for OpenVINO iGPU

**As a** user running setup
**I want** Phi-4-mini downloaded and optimized for OpenVINO iGPU
**So that** I have a fast general-purpose chat model on the iGPU

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 2
**Estimate Rationale:** Establishes the OpenVINO conversion pipeline pattern; subsequent iGPU models reuse this pattern

### Acceptance Criteria
- [ ] Downloads Phi-4-mini (3.8B) from Hugging Face
- [ ] Converts to OpenVINO IR format with INT4 quantization
- [ ] Output size approximately 3.0 GB
- [ ] Stores in `~/.oldintelclaw/models/openvino/phi-4-mini/`
- [ ] Registers in `manifest.json` with metadata (name, size, backend, path)
- [ ] Verifies model loads in OpenVINO with GPU device

### Technical Details
- **Files:** `scripts/models/convert_phi4mini.py`
- **Method:** `optimum-cli export openvino --model microsoft/Phi-4-mini-instruct --weight-format int4 --output ~/.oldintelclaw/models/openvino/phi-4-mini/`
- **Dependencies:** OpenVINO (Story 2.2), model store (Story 4.1), download engine (Story 4.2)

### Testing Plan
- [ ] Integration test: model loads in OpenVINO Core
- [ ] Integration test: GPU device accepts the model
- [ ] Verify output file size is in expected range

### Definition of Done
- Phi-4-mini INT4 model files exist in model store
- Model loadable by OpenVINO on GPU device
- Registered in manifest.json

---

## User Story 4.4: DeepSeek-R1-Distill-Qwen-7B INT4 for ITREX

**As a** user running setup
**I want** DeepSeek-R1-Distill-Qwen-7B optimized for ITREX CPU inference
**So that** I have a strong reasoning model for complex tasks

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 2
**Estimate Rationale:** Establishes the ITREX quantization pipeline pattern; follows OpenVINO pattern from 4.3

### Acceptance Criteria
- [ ] Downloads DeepSeek-R1-Distill-Qwen-7B from Hugging Face
- [ ] Applies INT4 weight-only quantization via ITREX
- [ ] Output size approximately 5.2 GB
- [ ] Stores in `~/.oldintelclaw/models/itrex/deepseek-r1-distill-qwen-7b/`
- [ ] Registers in `manifest.json`
- [ ] Verifies model loads with ITREX runtime

### Technical Details
- **Files:** `scripts/models/convert_deepseek_r1.py`
- **Method:** ITREX `WeightOnlyQuantConfig(weight_dtype="int4")` applied to model
- **Dependencies:** ITREX (Story 2.5), model store (Story 4.1), download engine (Story 4.2)

### Testing Plan
- [ ] Integration test: model loads with ITREX
- [ ] Integration test: test inference produces valid output
- [ ] Verify output file size is in expected range

### Definition of Done
- DeepSeek-R1 INT4 model files in model store
- Model loadable by ITREX
- Registered in manifest.json

---

## User Story 4.5: Gemma 3 4B INT4 for OpenVINO iGPU

**As a** user running setup
**I want** Gemma 3 4B optimized for OpenVINO iGPU
**So that** I have a vision-capable model for multimodal tasks

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P1 (High)
**Sprint:** Sprint 2
**Estimate Rationale:** Follows established OpenVINO pipeline from Story 4.3

### Acceptance Criteria
- [ ] Downloads Gemma 3 4B from Hugging Face
- [ ] Converts to OpenVINO IR format with INT4 quantization
- [ ] Output size approximately 3.2 GB
- [ ] Stores in `~/.oldintelclaw/models/openvino/gemma-3-4b/`
- [ ] Registers in `manifest.json`
- [ ] Verifies model loads in OpenVINO with GPU device

### Technical Details
- **Files:** `scripts/models/convert_gemma3.py`
- **Method:** `optimum-cli export openvino --model google/gemma-3-4b-it --weight-format int4`
- **Dependencies:** OpenVINO (Story 2.2), model store (Story 4.1)

### Testing Plan
- [ ] Integration test: model loads in OpenVINO Core on GPU
- [ ] Verify output file size is in expected range

### Definition of Done
- Gemma 3 4B INT4 model files in model store
- Model loadable by OpenVINO on GPU device
- Registered in manifest.json

---

## User Story 4.6: Qwen3-8B-Thinking INT4 for ITREX

**As a** user running setup
**I want** Qwen3-8B-Thinking optimized for ITREX CPU inference
**So that** I have a multilingual coding and thinking model

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P2 (Medium)
**Sprint:** Sprint 2
**Estimate Rationale:** Follows established ITREX pipeline from Story 4.4

### Acceptance Criteria
- [ ] Downloads Qwen3-8B-Thinking from Hugging Face
- [ ] Applies INT4 weight-only quantization via ITREX
- [ ] Output size approximately 5.5 GB
- [ ] Stores in `~/.oldintelclaw/models/itrex/qwen3-8b-thinking/`
- [ ] Registers in `manifest.json`
- [ ] Verifies model loads with ITREX runtime

### Technical Details
- **Files:** `scripts/models/convert_qwen3.py`
- **Method:** ITREX `WeightOnlyQuantConfig(weight_dtype="int4")`
- **Dependencies:** ITREX (Story 2.5), model store (Story 4.1)

### Testing Plan
- [ ] Integration test: model loads with ITREX
- [ ] Verify output file size is in expected range

### Definition of Done
- Qwen3-8B INT4 model files in model store
- Model loadable by ITREX
- Registered in manifest.json

---

## User Story 4.7: SmolLM3-3B for ZeroClaw Native

**As a** user running setup
**I want** SmolLM3-3B prepared for ZeroClaw's native GGUF execution
**So that** I have a fast background agent model with minimal overhead

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P1 (High)
**Sprint:** Sprint 2
**Estimate Rationale:** GGUF download only, no conversion needed — OpenVINO GenAI handles GGUF directly

### Acceptance Criteria
- [ ] Downloads SmolLM3-3B in GGUF format (INT4 quantized) from Hugging Face
- [ ] Output size approximately 2.2 GB
- [ ] Stores in `~/.oldintelclaw/models/gguf/smollm3-3b/`
- [ ] Registers in `manifest.json`
- [ ] Verifies GGUF file integrity via checksum

### Technical Details
- **Files:** `scripts/models/download_smollm3.sh`
- **Method:** Direct GGUF download — no conversion step needed
- **Dependencies:** Model store (Story 4.1), download engine (Story 4.2)

### Testing Plan
- [ ] Integration test: GGUF file is valid and loadable
- [ ] Verify file size is in expected range

### Definition of Done
- SmolLM3-3B GGUF file in model store
- Registered in manifest.json
- Checksum verified

---

# Epic 5: Inference Server & Integration

**Goal:** Launch inference servers for all model backends and pair them with the ZeroClaw gateway. Validate that performance targets are met.
**Sprint:** Sprint 3
**Story Points:** 10

---

## User Story 5.1: OpenVINO Model Server (OVMS) Launch

**As a** user completing setup
**I want** the OpenVINO Model Server started with iGPU models loaded
**So that** Phi-4-mini and Gemma 3 4B are available for inference

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Launches OVMS (or compatible server) with OpenVINO iGPU models
- [ ] Configures model repository pointing to `~/.oldintelclaw/models/openvino/`
- [ ] Binds to `localhost:8000` (configurable port)
- [ ] Serves OpenAI-compatible `/v1/chat/completions` endpoint
- [ ] Generates systemd user service unit for persistence (optional)
- [ ] Health check endpoint responds at `/v1/models`

### Technical Details
- **Files:** `src/server/ovms.rs` (or `scripts/server/ovms.sh`)
- **Config:** `~/.oldintelclaw/ovms_config.json` with model paths and device targets
- **Dependencies:** OpenVINO (Story 2.2), iGPU models (Stories 4.3, 4.5)

### Testing Plan
- [ ] Integration test: `/v1/models` returns model list
- [ ] Integration test: `/v1/chat/completions` returns valid response
- [ ] Integration test: models running on GPU device (not CPU fallback)

### Definition of Done
- OVMS running and serving models on iGPU
- API endpoint accessible at localhost:8000
- Health check passes

---

## User Story 5.2: llama-server with OpenVINO Backend

**As a** user completing setup
**I want** llama-server available as an alternative inference backend
**So that** GGUF models (SmolLM3) can be served with OpenVINO acceleration

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Installs or builds `llama-server` with OpenVINO backend support
- [ ] Configures to serve GGUF models from `~/.oldintelclaw/models/gguf/`
- [ ] Binds to `localhost:8001` (separate port from OVMS)
- [ ] Serves OpenAI-compatible API
- [ ] Supports concurrent requests

### Technical Details
- **Files:** `src/server/llama_server.rs` (or `scripts/server/llama_server.sh`)
- **Method:** Build llama.cpp with OpenVINO backend, or install pre-built binary
- **Dependencies:** OpenVINO (Story 2.2), GGUF models (Story 4.7)

### Testing Plan
- [ ] Integration test: server starts and responds to health check
- [ ] Integration test: `/v1/chat/completions` with SmolLM3-3B returns valid response

### Definition of Done
- llama-server running with OpenVINO backend
- GGUF model serving on localhost:8001
- API endpoint functional

---

## User Story 5.3: ITREX Inference Endpoint

**As a** user completing setup
**I want** an inference endpoint for ITREX CPU-bound models
**So that** DeepSeek-R1 and Qwen3 thinking models are accessible via API

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Launches a Python-based inference server for ITREX models
- [ ] Serves models from `~/.oldintelclaw/models/itrex/`
- [ ] Binds to `localhost:8002` (separate port)
- [ ] Serves OpenAI-compatible `/v1/chat/completions` endpoint
- [ ] Supports model selection via request body

### Technical Details
- **Files:** `scripts/server/itrex_server.py`
- **Method:** FastAPI or Flask server wrapping ITREX inference, or use `text-generation-inference` with ITREX backend
- **Dependencies:** ITREX (Story 2.5), INT4 models (Stories 4.4, 4.6)

### Testing Plan
- [ ] Integration test: server starts and lists available models
- [ ] Integration test: inference request returns valid response
- [ ] Performance test: ITREX models respond within acceptable latency

### Definition of Done
- ITREX server running on localhost:8002
- Both DeepSeek-R1 and Qwen3 models servable
- API endpoint functional

---

## User Story 5.4: ZeroClaw Gateway Pairing

**As a** user completing setup
**I want** ZeroClaw paired with all local inference endpoints
**So that** the agent framework can route requests to the right model/backend

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Updates `~/.oldintelclaw/config.toml` with all server endpoints:
  - OVMS at localhost:8000 (Phi-4-mini, Gemma 3 4B)
  - llama-server at localhost:8001 (SmolLM3-3B)
  - ITREX at localhost:8002 (DeepSeek-R1, Qwen3)
- [ ] Verifies ZeroClaw can reach each endpoint
- [ ] Tests a round-trip inference call through ZeroClaw
- [ ] Sets default model routing (e.g., general → Phi-4-mini, reasoning → DeepSeek-R1)
- [ ] Prints pairing success message with available models

### Technical Details
- **Files:** `src/config/pairing.rs` (or `scripts/config/pairing.sh`)
- **Method:** Update config.toml, then run `zeroclaw ping` or equivalent health check
- **Dependencies:** All servers running (Stories 5.1, 5.2, 5.3), ZeroClaw (Story 3.1)

### Testing Plan
- [ ] Integration test: ZeroClaw routes request to correct backend
- [ ] Integration test: all five models accessible through ZeroClaw
- [ ] Integration test: default routing works as expected

### Definition of Done
- ZeroClaw paired with all three inference servers
- Round-trip inference succeeds through ZeroClaw
- Default model routing configured

---

## User Story 5.5: Performance Validation

**As a** user who completed setup
**I want** a benchmark that validates performance targets
**So that** I know my setup meets the PRD requirements

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P1 (High)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Measures Time-to-First-Token (TTFT) for iGPU models (target: < 500ms)
- [ ] Measures Tokens per Second (TPS) for 4B-class models on iGPU (target: > 15 t/s)
- [ ] Measures ZeroClaw cold start time (target: < 10ms)
- [ ] Monitors memory usage during 4k context inference (target: no swap)
- [ ] Produces benchmark report saved to `~/.oldintelclaw/benchmark.log`
- [ ] Reports PASS/WARN/FAIL for each metric against targets

### Technical Details
- **Files:** `scripts/benchmark/performance.py` (or `scripts/benchmark/performance.sh`)
- **Method:** Timed inference calls with token counting, `/proc/self/status` for memory, `time` for cold start
- **Dependencies:** All servers running, ZeroClaw paired (Story 5.4)

### Testing Plan
- [ ] Integration test on target i7-1185G7 hardware
- [ ] Verify metrics are within expected ranges
- [ ] Verify no disk swapping during 4k context test

### Definition of Done
- Benchmark report generated with all four metrics
- Results compared against PRD targets
- Report saved to log file

---

# Epic 6: CLI UX, Error Handling & Documentation

**Goal:** Polish the setup experience with proper CLI ergonomics, error handling, progress reporting, and documentation. Ensure the "zero-config" promise holds up in practice.
**Sprint:** Sprint 3
**Story Points:** 9

---

## User Story 6.1: CLI Argument Parsing and Help System

**As a** user running the setup tool
**I want** clear CLI arguments and a help system
**So that** I can customize the setup process and understand available options

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Main entry point: `./setup.sh` (or `oldintelclaw setup`)
- [ ] Supports `--help` with usage information
- [ ] Supports `--dry-run` (show what would be done without doing it)
- [ ] Supports `--skip-models` (install stack only, skip model downloads)
- [ ] Supports `--skip-kernel` (skip kernel parameter optimization)
- [ ] Supports `--verbose` (detailed logging output)
- [ ] Supports `--verify-only` (run verification suite without installing)
- [ ] Returns appropriate exit codes (0 = success, 1 = failure, 2 = partial)

### Technical Details
- **Files:** `setup.sh` (main entry point) or `src/main.rs` (if Rust CLI)
- **Method:** Shell `getopts` or Rust `clap` for argument parsing
- **Dependencies:** None

### Testing Plan
- [ ] Unit test: `--help` prints usage and exits 0
- [ ] Unit test: `--dry-run` produces plan without side effects
- [ ] Unit test: unknown flags print error and exit 1
- [ ] Unit test: `--verify-only` runs checks without installation

### Definition of Done
- All flags documented in `--help` output
- Exit codes consistent
- Dry-run mode produces accurate plan

---

## User Story 6.2: Structured Error Handling and Rollback

**As a** user whose setup encounters an error
**I want** clear error messages and safe failure behavior
**So that** my system is not left in a broken half-configured state

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Each setup step is wrapped in error handling
- [ ] On failure, prints clear error message with remediation suggestion
- [ ] Tracks completed steps in `~/.oldintelclaw/.setup-state.json`
- [ ] On re-run, resumes from last failed step (not from scratch)
- [ ] `--reset` flag clears state file to force fresh run
- [ ] No step leaves the system in an inconsistent state (atomic where possible)

### Technical Details
- **Files:** `src/error/handler.rs` (or `scripts/error/handler.sh`)
- **State file format:**
  ```json
  {
    "version": 1,
    "last_run": "2026-03-30T12:00:00Z",
    "steps": {
      "cpu_audit": "complete",
      "os_audit": "complete",
      "intel_packages": "failed",
      "openvino": "pending"
    }
  }
  ```
- **Dependencies:** None (cross-cutting concern)

### Testing Plan
- [ ] Unit test: state file written correctly after each step
- [ ] Unit test: resume from failed step on re-run
- [ ] Unit test: `--reset` clears state file
- [ ] Integration test: simulate failure mid-setup, verify resume works

### Definition of Done
- Error messages are actionable
- State file tracks progress
- Re-run resumes from failure point
- `--reset` works

---

## User Story 6.3: Logging and Diagnostics Output

**As a** user troubleshooting a setup issue
**I want** detailed logs saved to a file
**So that** I can share diagnostics when asking for help

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P1 (High)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] All setup output logged to `~/.oldintelclaw/setup.log`
- [ ] Log includes timestamps, step names, and outcomes
- [ ] Normal mode shows summary output; `--verbose` shows full detail
- [ ] Log file rotated (keep last 5 runs)
- [ ] Sensitive data (paths with usernames) not logged to shared outputs

### Technical Details
- **Files:** `src/logging/logger.rs` (or `scripts/logging/logger.sh`)
- **Method:** Tee output to both stdout and log file
- **Dependencies:** None

### Testing Plan
- [ ] Unit test: log file created with expected format
- [ ] Unit test: verbose mode includes additional detail
- [ ] Unit test: log rotation keeps only 5 files

### Definition of Done
- Log file generated on every run
- Timestamps and step names present
- Rotation works

---

## User Story 6.4: Progress Reporting for Long Operations

**As a** user waiting for model downloads or compilation
**I want** progress indicators for long-running operations
**So that** I know the setup hasn't stalled

**Type:** [FEATURE]
**Story Points:** 1
**Priority:** P1 (High)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Model downloads show progress bar (percentage, speed, ETA)
- [ ] Rust compilation (`cargo install`) shows spinner with elapsed time
- [ ] DNF installation shows package progress
- [ ] Each major step prints a "Step N/8: {description}" header
- [ ] Estimated total time displayed at start (based on component count)

### Technical Details
- **Files:** `src/ui/progress.rs` (or `scripts/ui/progress.sh`)
- **Method:** Terminal progress bars using `indicatif` (Rust) or `tqdm` (Python) or shell escape sequences
- **Dependencies:** None

### Testing Plan
- [ ] Manual test: progress bars render correctly in terminal
- [ ] Unit test: step counter increments correctly

### Definition of Done
- All long operations show progress
- Step headers visible for major phases
- No silent hangs during setup

---

## User Story 6.5: End-to-End Integration Test

**As a** developer maintaining OldIntelClaw
**I want** an automated end-to-end test of the full setup process
**So that** regressions are caught before release

**Type:** [FEATURE]
**Story Points:** 2
**Priority:** P0 (Critical)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] Runs the full setup workflow on target hardware
- [ ] Verifies each epic's acceptance criteria programmatically
- [ ] Tests idempotency: runs setup twice, second run completes without errors
- [ ] Tests `--dry-run` mode produces expected plan
- [ ] Tests `--verify-only` mode checks all components
- [ ] Produces test report with pass/fail per story
- [ ] Can be run via `./tests/e2e/test_full_setup.sh`

### Technical Details
- **Files:** `tests/e2e/test_full_setup.sh` (BATS framework)
- **Method:** BATS (Bash Automated Testing System) for shell-level integration testing
- **Dependencies:** Target i7-1185G7 hardware, all components

### Testing Plan
- [ ] Run on target hardware with clean system
- [ ] Run on target hardware with existing installation (idempotency)
- [ ] Verify all assertions pass

### Definition of Done
- E2E test script exists and runs
- All assertions pass on target hardware
- Idempotency verified

---

## User Story 6.6: User Documentation

**As a** user discovering OldIntelClaw
**I want** clear documentation on how to use the tool
**So that** I can get started without reading the source code

**Type:** [CHORE]
**Story Points:** 1
**Priority:** P1 (High)
**Sprint:** Sprint 3

### Acceptance Criteria
- [ ] README.md updated with final CLI usage and examples
- [ ] `docs/TROUBLESHOOTING.md` created with common issues and solutions
- [ ] `docs/MODELS.md` created with model portfolio details and selection guide
- [ ] `--help` output matches documentation
- [ ] Quick start section tested by a fresh reader

### Technical Details
- **Files:** `README.md`, `docs/TROUBLESHOOTING.md`, `docs/MODELS.md`
- **Dependencies:** All features complete

### Testing Plan
- [ ] Review documentation against actual CLI behavior
- [ ] Verify quick start steps work on clean system

### Definition of Done
- README reflects final tool behavior
- Troubleshooting guide covers known issues
- Model guide helps users choose the right model
