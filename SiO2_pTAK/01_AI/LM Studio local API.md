# LM Studio (local API)

## Description
LM Studio is a desktop application for running and managing local LLMs, providing a user-friendly interface and a local API server that mimics OpenAI's API for seamless integration. It allows loading, quantizing, and serving models like GGUF files, enabling developers to build applications around local AI without cloud dependencies.

## Features
- **Model Management**: Download, load, and manage LLM files from sources like Hugging Face.
- **Local Server**: Exposes an OpenAI-compatible API for chat completions, embeddings, etc.
- **Quantization Tools**: Optimize models for CPU/GPU with reduced bit precision.
- **UI for Testing**: Built-in chat interface for model interaction.
- **Hardware Acceleration**: Supports NVIDIA CUDA, Apple Metal, or CPU fallback.
- **Preset Configurations**: Templates for popular models and fine-tunes.

## Relevance to Current Build
Serves as the primary interface for hosting Local LLMs in the AI/Orchestration Layer, enabling multi-model orchestration and integration with VS Code workflows. It connects to persistent memory for stateful interactions and supports RAG pipelines by providing embeddings.

## Related Components
- [[01_AI/Local LLMs DeepSeek, Qwen, Nous Hermes, Dolphin|Local LLMs (DeepSeek, Qwen, Nous Hermes, Dolphin)]]: The models hosted and served via LM Studio.
- [[OpenAI API]]: Compatible API structure allows hybrid use.
- [[Multi-model orchestration logic]]: Routes API calls through LM Studio for local models.
- [[01_AI/Persistent memory Azure SQL - local DB|Persistent memory (Azure SQL / local DB)]]: Integrates for memory persistence in API sessions.
- [[VS Code agent workflows]]: Uses LM Studio's API for AI-assisted coding.
- [[RAG pipelines]]: Leverages LM Studio for embedding generation in retrieval.
