# Local LLMs (DeepSeek, Qwen, Nous Hermes, Dolphin)

## Description
Local Large Language Models (LLMs) refer to AI models that run on local hardware without relying on cloud services. These include specific models like DeepSeek (a family of efficient, high-performance models for coding and general tasks), Qwen (Alibaba's open-source models excelling in multilingual capabilities and reasoning), Nous Hermes (fine-tuned versions of Llama models focused on instruction-following and helpfulness), and Dolphin (uncensored variants of Mistral models emphasizing creativity and reduced safety constraints). They enable offline AI processing, reducing latency and enhancing privacy.

## Features
- **Offline Operation**: Run entirely on local compute, no internet required.
- **Customization**: Fine-tunable for specific tasks like coding, chat, or orchestration.
- **Model Variants**: DeepSeek for math/coding; Qwen for multilingual; Nous Hermes for role-playing/instructions; Dolphin for uncensored responses.
- **Quantization Support**: Reduced precision (e.g., 4-bit) for lower resource use.
- **API Compatibility**: Often compatible with OpenAI-style APIs for easy integration.
- **Inference Engines**: Support for frameworks like GGUF, Hugging Face Transformers.

## Relevance to Current Build
In the AI/Orchestration Layer, these local LLMs form the core of on-device intelligence, integrated via LM Studio for API access. They handle tasks like agent workflows in VS Code, RAG pipelines for knowledge retrieval, and multi-model orchestration to switch between models based on query type. Persistent memory via Azure SQL/local DB stores context for ongoing sessions.

## Related Components
- [[01_AI/LM Studio local API|LM Studio (local API)]]: Provides the API endpoint for running and querying these LLMs locally.
- [[OpenAI API]]: Fallback or hybrid orchestration when local models are insufficient.
- [[Multi-model orchestration logic]]: Logic to select and route queries among these LLMs and others.
- [[01_AI/Persistent memory Azure SQL - local DB|Persistent memory (Azure SQL / local DB)]]: Stores conversation history and embeddings for these models.
- [[VS Code agent workflows]]: Uses these LLMs for code generation and automation in development.
- [[Codex]]: Potentially integrates with these for code-specific tasks (if Codex refers to OpenAI's code model).
- [[RAG pipelines]]: Enhances these LLMs with retrieval-augmented generation using local data.
