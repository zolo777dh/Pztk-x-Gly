# Workspace design notes — 0.3.0

The design combines the existing dark blue / gold application identity with a persistent task workspace. The goal is to keep addon investigation, code review, recovery and profile preparation in the same desktop application.

## References reviewed

Official documentation was retrieved from these public repositories. The research concerns workflow patterns, not copied application code or visual assets.

- [VS Code: chat context](https://github.com/microsoft/vscode-docs/blob/7f0009b18ff2e915d9c286b1af09666c46be8c02/docs/chat/copilot-chat-context.md): explicit files and workspace context help a model answer questions about the current project.
- [VS Code: review code edits](https://github.com/microsoft/vscode-docs/blob/7f0009b18ff2e915d9c286b1af09666c46be8c02/docs/agents/run/review-code-edits.md): dedicated review, file changes and restoration are distinct stages of an assistant workflow.
- [Zed: agent panel](https://github.com/zed-industries/zed/blob/fae8a354829e56bf5615fedfa8cdfecb124550c4/docs/src/ai/agent-panel.md): task threads and contextual conversations keep related work together.

Direct access to the VS Code, Zed and Cursor product websites was denied by the cloud network gateway. The conclusions above use the retrieved official GitHub documentation. No detailed evaluation of Cursor's current product is claimed.

## Implemented choices

- A task list, conversation, Context and Changes tabs form the AI workspace. The website can be docked beside the task.
- Selected addons are indexed together. Loader references and lexical symbol matches help select bounded excerpts instead of sending entire projects.
- A prepared request can be inspected before transmission. Source hashes pin the code used to prepare it.
- Browser subscription mode, local API and cloud API share one reply / review / backup / apply workflow.
- Files can be accepted individually; a verified backup precedes writes. Recovery refuses to overwrite later user edits.
- The straightforward specialization → dungeon / boss → ability → defensive set flow remains the default planner interface.
- NSR and NSRT retain their native export formats and different reminder semantics. Game clients have separate profile workspaces.

## Boundaries

Lexical symbol links do not prove that two Lua namespaces are the same at runtime. Static diagnostics are advisory for API compatibility. The app does not execute generated Lua against a running game. Website login and availability remain controlled by ChatGPT / Claude; their authenticated sessions were not tested here. Website requests and replies are transferred manually, including in the embedded panel. NSRT scheduling is distinct from NSR's cooldown-based defensive priority selection.
