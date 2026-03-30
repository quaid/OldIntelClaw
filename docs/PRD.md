# PRD: "OldIntelClaw" Local Agent Environment Orchestrator

## 1. Executive Summary
The "OldIntelClaw" project aims to provide a zero-config, automated environment setup for running the ultra-lightweight **ZeroClaw** agent framework on 11th Gen Intel hardware. This solution leverages the **OpenVINO** toolkit and **Intel Extension for Transformers (ITREX)** to maximize the inference performance of 1B–8B parameter models on mobile processors with limited RAM (16GB), utilizing the Iris Xe iGPU for acceleration.

## 2. Target Hardware & OS Profile
*   **Processor:** 11th Gen Intel® Core™ i7-1185G7 (Tiger Lake).
*   **Memory:** 16 GB RAM (The "hardware poverty line" for 2026 local AI).
*   **Graphics:** Intel Iris Xe iGPU (96 Execution Units).
*   **Operating System:** Fedora 42 Linux (x86_64).

## 3. Functional Requirements

### 3.1 Automated Dependency Orchestration
The app must automate the installation of the complete Intel AI stack on Fedora 42:
*   **System Packages:** `openvino`, `intel-compute-runtime`, `intel-level-zero-gpu`, `level-zero`, and `intel-media-driver`.
*   **Hardware Access:** Automatically add the current user to the `video` and `render` groups to enable iGPU passthrough.
*   **Build Tools:** Install the Rust toolchain for ZeroClaw and Python 3.12+ for the ITREX backend.

### 3.2 ZeroClaw Implementation
The orchestrator will deploy **ZeroClaw** (Rust-based) as the primary agent framework because it consumes less than **5MB of idle RAM**, leaving 99% of the 16GB budget for the AI models.[1]
*   **Migration Path:** Include a logic block to migrate existing OpenClaw `SKILL.md` or workspace files if detected.[1]
*   **Local Server Config:** Automatically configure ZeroClaw's `config.toml` to point to local inference endpoints (e.g., `llamacpp` or `custom` providers).

### 3.3 Model Optimization & Management
The app will fetch and prepare models in the **1B–8B parameter range** using **INT4/NF4 weight-only quantization** to prevent OOM (Out of Memory) crashes.
*   **Quantization Engine:** Use ITREX for CPU-bound "Thinking" models and OpenVINO Model Optimizer for iGPU-bound models.
*   **Model Store:** Maintain an optimized repository of OpenVINO IR and GGUF files in `~/.intelliclaw/models/`.

## 4. Best Methods for Model Execution

On a 16GB i7-1185G7 system, the application must choose the execution path based on the model's architecture:

| Method | Best For | Technical implementation |
| :--- | :--- | :--- |
| **OpenVINO iGPU** | Multimodal & General Chat | Offload model weights to Iris Xe iGPU using the OpenVINO runtime. This reduces CPU load and increases generation speed by 3x–10x. |
| **ITREX INT4** | "Thinking" & Reasoning | Use **Intel Extension for Transformers** with `nf4` or `int4` weight-only quantization for DeepSeek-R1 style models. This preserves reasoning accuracy while fitting in ~5GB RAM. |
| **OpenVINO GenAI** | GGUF Direct Execution | Use the `GGUFReaderV2` in OpenVINO GenAI for direct execution of GGUF models without manual conversion, leveraging graph translation logic. |

## 5. Optimized Model Portfolio (16GB Tiers)

| Model | Size | Quant | Recommended Backend |
| :--- | :--- | :--- | :--- |
| **Phi-4-mini (3.8B)** | 3.0 GB | INT4 | **OpenVINO iGPU** (Highest speed) |
| **DeepSeek-R1-Distill-Qwen-7B** | 5.2 GB | INT4 | **ITREX CPU** (Complex reasoning) |
| **Gemma 3 4B** | 3.2 GB | INT4 | **OpenVINO iGPU** (Vision tasks) |
| **Qwen3-8B-Thinking** | 5.5 GB | INT4 | **ITREX CPU** (Multilingual coding) |
| **SmolLM3-3B** | 2.2 GB | INT4 | **ZeroClaw Native** (Fast background agent) |

## 6. Execution Workflow (The "Setup" Command)
1.  **System Audit:** Check for 11th Gen+ CPU and Fedora 42.
2.  **Kernel Optimization:** (Optional) Set `i915.enable_guc=3` and `i915.enable_fbc=1` for better power/perf balance.
3.  **Dependency Pulse:** `dnf install` OpenVINO, Compute Runtime, and Rust.
4.  **Security Handshake:** `usermod -aG video,render $USER`.
5.  **ZeroClaw Build:** `cargo install zeroclaw`.
6.  **Model Pull:** Download **Phi-4-mini** and **DeepSeek-R1-Distill-7B** in INT4.
7.  **Inference Server:** Launch `ovms` (OpenVINO Model Server) or `llama-server` with the OpenVINO backend.
8.  **Pairing:** Link the local CLI to the ZeroClaw gateway.[1]

## 7. Performance Targets
*   **Time-to-First-Token (TTFT):** < 500ms on iGPU.
*   **Tokens per Second (TPS):** > 15 t/s for 4B-class models on iGPU.
*   **Cold Start:** < 10ms for the ZeroClaw agent framework itself.
*   **Reliability:** Zero disk-swapping during standard 4k context inference.
