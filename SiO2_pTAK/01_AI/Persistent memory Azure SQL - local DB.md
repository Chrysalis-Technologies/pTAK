# Persistent memory (Azure SQL / local DB)

## Description
Persistent memory refers to databases that store AI context, embeddings, and state for long-term recall, using Azure SQL for cloud scalability or local DB (e.g., SQLite/PostgreSQL) for offline use. It enables stateful AI interactions beyond single sessions.

## Features
- **Data Storage**: Key-value, vector, or relational storage for contexts and vectors.
- **Querying**: SQL for structured data, vector search for embeddings.
- **Synchronization**: Hybrid local-cloud sync.
- **Security**: Encryption, access controls.
- **Scalability**: Azure for high availability, local for low latency.
- **Integration**: APIs for AI frameworks like LangChain.

## Relevance to Current Build
Supports the AI/Orchestration Layer by storing memory for LLMs, orchestration, and RAG. Integrates with Azure SQL for cloud ops and local DB for edge scenarios.

## Related Components
- [[01_AI/Local LLMs DeepSeek, Qwen, Nous Hermes, Dolphin|Local LLMs (DeepSeek, Qwen, Nous Hermes, Dolphin)]]: Stores conversation history.
- [[01_AI/LM Studio local API|LM Studio (local API)]]: Persists sessions via DB.
- [[OpenAI API]]: Hybrid memory sharing.
- [[Multi-model orchestration logic]]: Uses DB for context routing.
- [[VS Code agent workflows]]: Stores workflow states.
- [[RAG pipelines]]: Holds embeddings and retrieved data.
- [[Azure SQL Database]]: Cloud implementation.
- [[Local SQL Server]]: Local implementation.
