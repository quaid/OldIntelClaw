# OldIntelClaw

Zero-config, automated environment setup for running the [ZeroClaw](https://github.com/zeroclaw) agent framework on 11th Gen Intel hardware.

OldIntelClaw leverages the OpenVINO toolkit and Intel Extension for Transformers (ITREX) to maximize inference performance of 1B-8B parameter models on mobile processors with limited RAM (16GB), utilizing the Iris Xe iGPU for acceleration.

## Target Hardware

| Component | Spec |
|-----------|------|
| Processor | 11th Gen Intel Core i7-1185G7 (Tiger Lake) |
| Memory | 16 GB RAM |
| Graphics | Intel Iris Xe iGPU (96 Execution Units) |
| OS | Fedora 42 Linux (x86_64) |

## What It Does

- **Automated dependency orchestration** - Installs the complete Intel AI stack (`openvino`, `intel-compute-runtime`, `level-zero`, etc.) and configures hardware access
- **ZeroClaw deployment** - Sets up the Rust-based agent framework (<5MB idle RAM) with local inference endpoints
- **Model optimization** - Fetches and quantizes models (INT4/NF4) to fit within the 16GB RAM budget
- **Inference routing** - Selects the optimal execution path (iGPU, ITREX CPU, or GenAI) based on model architecture

## Supported Models

| Model | Size | Backend |
|-------|------|---------|
| Phi-4-mini (3.8B) | 3.0 GB | OpenVINO iGPU |
| DeepSeek-R1-Distill-Qwen-7B | 5.2 GB | ITREX CPU |
| Gemma 3 4B | 3.2 GB | OpenVINO iGPU |
| Qwen3-8B-Thinking | 5.5 GB | ITREX CPU |
| SmolLM3-3B | 2.2 GB | ZeroClaw Native |

All models use INT4 quantization.

## Performance Targets

- **Time-to-First-Token:** < 500ms on iGPU
- **Throughput:** > 15 tokens/sec for 4B-class models on iGPU
- **Cold Start:** < 10ms for the ZeroClaw agent framework
- **Reliability:** Zero disk-swapping during standard 4k context inference

## Prerequisites

- 11th Gen (or newer) Intel processor with Iris Xe iGPU
- Fedora 42 Linux
- 16 GB RAM (minimum)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/quaid/OldIntelClaw.git
cd OldIntelClaw

# Run the setup (coming soon)
./setup.sh
```

The setup command will:
1. Audit your system for compatible hardware
2. Install OpenVINO, Compute Runtime, and Rust toolchain
3. Configure iGPU access (`video` and `render` groups)
4. Build and install ZeroClaw
5. Download default models (Phi-4-mini, DeepSeek-R1-Distill-7B) in INT4
6. Launch the local inference server
7. Pair the CLI with the ZeroClaw gateway

## Project Structure

```
OldIntelClaw/
├── docs/
│   └── PRD.md              # Product requirements document
├── .ainative/              # AINative Studio project config
│   ├── AINATIVE.md         # Project context (local)
│   ├── settings.local.json # Project settings (local)
│   ├── commands/           # Shared commands (symlink)
│   ├── rules/              # Shared rules (symlink)
│   ├── hooks/              # Shared hooks (symlink)
│   └── skills/             # Shared skills (symlink)
└── .gitignore
```

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
