# OldIntelClaw: Future Features Roadmap

**Last Updated:** 2026-04-02
**Status:** Living document — updated as features are proposed or reprioritized

---

## Current Scope (v0.1.0)

Fedora 42 on 11th Gen Intel i7-1185G7 with 16GB RAM. Single-distro, single-hardware-generation, bash-based orchestration. See `docs/planning/BACKLOG.md` for the active backlog.

---

## Phase 2: Multi-Distro Support

### Distro Detection and Package Manager Abstraction
- Detect Linux distribution from `/etc/os-release` (already partially done in Story 1.2)
- Abstract package installation behind a distro-aware layer:
  - **Fedora/RHEL/CentOS:** `dnf`
  - **Ubuntu/Debian:** `apt`
  - **Arch:** `pacman`
  - **openSUSE:** `zypper`
  - **NixOS:** `nix-env` / flake
- Map Intel package names across distro repositories (names differ: `intel-compute-runtime` vs `intel-opencl-icd` vs AUR packages)
- Handle distro-specific quirks (Ubuntu needs Intel APT repo added, Arch uses AUR for some packages)

### Broader Intel Generation Support
- Extend CPU audit to support 10th Gen (Ice Lake) with reduced feature set
- Add Intel Arc discrete GPU support (DG2/Alchemist) alongside iGPU
- Support Core Ultra / Meteor Lake integrated NPU for future model offload
- Detect and configure multiple Intel GPU devices when present

### Kernel Parameter Portability
- Abstract kernel parameter management across init systems (GRUB vs systemd-boot vs EFISTUB)
- Support `dracut` (Fedora/RHEL) and `update-initramfs` (Ubuntu/Debian)
- Detect secure boot and warn about unsigned module implications

---

## Phase 3: Model Management Improvements

### Model Registry and Discovery
- Local model registry with metadata (name, size, backend, quantization, benchmark scores)
- `oldintelclaw models list` — show installed models with status
- `oldintelclaw models add <name>` — download and optimize a new model
- `oldintelclaw models remove <name>` — clean up model files
- `oldintelclaw models benchmark <name>` — run performance tests

### Adaptive Model Selection
- Auto-select model based on available RAM at runtime
- Swap models when RAM pressure detected (e.g., drop 7B, load 3B)
- Profile-based model sets (e.g., "coding" profile loads DeepSeek + SmolLM, "chat" loads Phi-4)

### Model Update Pipeline
- Check Hugging Face for newer quantized versions
- `oldintelclaw models update` — re-download and re-quantize updated models
- Changelog tracking for model versions

---

## Phase 4: Runtime and Server Improvements

### Service Management
- systemd user service units for all inference servers (OVMS, llama-server, ITREX)
- `oldintelclaw start` / `oldintelclaw stop` / `oldintelclaw status`
- Auto-start on login (optional)
- Graceful shutdown with model unloading

### API Gateway
- Unified OpenAI-compatible endpoint that routes to correct backend
- Single port (e.g., localhost:8000) instead of three separate ports
- Request routing based on model name in the API call
- Health check aggregation across all backends

### Resource Monitoring
- Real-time RAM usage monitoring during inference
- iGPU utilization tracking via `intel_gpu_top`
- Automatic swap detection with warning
- Performance degradation alerts

---

## Phase 5: User Experience

### Interactive Setup Mode
- TUI (terminal UI) for setup with ncurses or similar
- Model selection menu (choose which models to install)
- Hardware capability summary before installation
- Estimated disk space and download time display

### Configuration Management
- `oldintelclaw config show` — display current configuration
- `oldintelclaw config set <key> <value>` — modify settings
- Config validation with schema
- Environment-specific configs (development, production)

### Diagnostics and Troubleshooting
- `oldintelclaw doctor` — comprehensive health check with remediation suggestions
- Log collection for bug reports (`oldintelclaw logs collect`)
- Hardware capability report for sharing

---

## Phase 6: Distribution and Packaging

### Package Distribution
- Fedora COPR repository for RPM distribution
- Flatpak for sandboxed installation
- AppImage for single-file portable distribution
- Docker/Podman container image for isolated environments

### Ansible/Puppet Integration
- Ansible role for fleet deployment
- Puppet module for enterprise management
- Terraform provider for cloud-provisioned Intel instances

---

## Phase 7: Advanced Features

### Multi-Model Orchestration
- Run multiple models simultaneously (e.g., fast 3B for autocomplete + 7B for complex tasks)
- Model chaining (fast model filters, thinking model reasons)
- Token budget management across concurrent models

### Remote Inference Fallback
- Configure remote API endpoints as fallback when local inference is insufficient
- Automatic failover: local iGPU → local CPU → remote API
- Cost tracking for remote API usage

### Plugin System
- ZeroClaw skill marketplace integration
- Custom model backend plugins
- Post-processing pipeline plugins (output filtering, formatting)

---

## Contributing

Feature requests and discussion welcome via GitHub Issues with the `enhancement` label. When proposing a feature, include:
- Use case (who benefits and how)
- Hardware/software requirements
- Rough complexity estimate
- Dependencies on other roadmap items
