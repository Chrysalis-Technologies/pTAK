# VS Code agent workflows

## Description
VS Code agent workflows involve AI-powered extensions or scripts in Visual Studio Code that automate development tasks, using agents (autonomous AI routines) for code generation, debugging, and orchestration.

## Features
- **AI Assistance**: Auto-complete, refactoring, bug fixing.
- **Workflow Automation**: Chains of agents for tasks like testing/deploying.
- **Integration**: With Git, Docker, and languages like Python/PowerShell.
- **Custom Agents**: Built with LLMs for specific domains.
- **Extensions**: Like GitHub Copilot or custom via API.
- **Collaboration**: Real-time sharing of workflows.

## Relevance to Current Build
In the AI/Orchestration Layer, leverages LLMs for dev automation in the overall system build, integrating with GitHub Actions and Dockerfiles.

## Related Components
- [[01_AI/Local LLMs DeepSeek, Qwen, Nous Hermes, Dolphin|Local LLMs (DeepSeek, Qwen, Nous Hermes, Dolphin)]]: Powers the agents.
- [[01_AI/LM Studio local API|LM Studio (local API)]]: API for local AI in VS Code.
- [[OpenAI API]]: Cloud AI for agents.
- [[Multi-model orchestration logic]]: Manages agents' model use.
- [[01_AI/Persistent memory Azure SQL - local DB|Persistent memory (Azure SQL / local DB)]]: Stores agent states.
- [[Codex]]: Code-focused AI integration.
- [[RAG pipelines]]: Enhances agents with knowledge retrieval.
- [[Git]]: Version control for workflows.
- [[GitHub Actions]]: Automates workflows.
- [[Python]]: Scripting for agents.
