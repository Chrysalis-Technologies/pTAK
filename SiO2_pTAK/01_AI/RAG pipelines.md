# RAG pipelines

## Description
Retrieval-Augmented Generation (RAG) pipelines combine retrieval of relevant documents/data with generative AI to produce informed responses, reducing hallucinations and incorporating external knowledge.

## Features
- **Embedding Generation**: Vectorize queries/documents.
- **Vector Search**: Find similar items in DB.
- **Generation Step**: LLM uses retrieved context.
- **Chunking/Indexing**: Efficient data handling.
- **Hybrid Search**: Keyword + semantic.
- **Evaluation**: Reranking and feedback loops.

## Relevance to Current Build
In AI/Orchestration, enhances LLMs with data from persistent memory, GIS files, or sensors, integrated into workflows.

## Related Components
- [[01_AI/Local LLMs DeepSeek, Qwen, Nous Hermes, Dolphin|Local LLMs (DeepSeek, Qwen, Nous Hermes, Dolphin)]]: Generation component.
- [[01_AI/LM Studio local API|LM Studio (local API)]]: Hosts RAG models.
- [[OpenAI API]]: For advanced embeddings.
- [[Multi-model orchestration logic]]: Routes RAG queries.
- [[01_AI/Persistent memory Azure SQL - local DB|Persistent memory (Azure SQL / local DB)]]: Stores vectors/documents.
- [[VS Code agent workflows]]: Uses RAG for code retrieval.
- [[Azure SQL Database]]: Vector storage.
- [[06_GIS/QGIS projects .qgz|QGIS projects (.qgz)]]: Source data for GIS RAG.
- [[GeoJSON]]: Data format in pipelines.
