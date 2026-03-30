# Project Context - OldIntelClaw

**Project**: OldIntelClaw - Local Agent Environment Orchestrator
**Description**: Zero-config automated environment setup for running the ZeroClaw agent framework on 11th Gen Intel hardware with OpenVINO and ITREX
**Target Hardware**: 11th Gen Intel Core i7-1185G7, 16GB RAM, Iris Xe iGPU
**OS**: Fedora 42 Linux (x86_64)
**Last Updated**: 2026-03-30

## Tech Stack
- **Agent Framework**: ZeroClaw (Rust-based, <5MB idle RAM)
- **AI Inference**: OpenVINO, Intel Extension for Transformers (ITREX)
- **GPU**: Intel Iris Xe iGPU (96 EUs) via OpenVINO runtime
- **Quantization**: INT4/NF4 weight-only quantization
- **Models**: 1B-8B parameter range (Phi-4-mini, DeepSeek-R1-Distill-7B, Gemma 3 4B, Qwen3-8B, SmolLM3-3B)

## Key Goals
- Automated Intel AI stack installation on Fedora 42
- ZeroClaw deployment with local inference endpoints
- Model optimization for 16GB RAM constraint
- TTFT < 500ms, TPS > 15 for 4B-class models on iGPU
